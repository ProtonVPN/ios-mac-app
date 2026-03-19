//
//  Created on 05/03/2026 by Max Kupetskyi.
//
//  Copyright (c) 2026 Proton AG
//
//  Proton VPN is free software: you can redistribute it and/or modify
//  it under the terms of the GNU General Public License as published by
//  the Free Software Foundation, either version 3 of the License, or
//  (at your option) any later version.
//
//  Proton VPN is distributed in the hope that it will be useful,
//  but WITHOUT ANY WARRANTY; without even the implied warranty of
//  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
//  GNU General Public License for more details.
//
//  You should have received a copy of the GNU General Public License
//  along with Proton VPN.  If not, see <https://www.gnu.org/licenses/>.

import Combine
import CommonNetworking
import Dependencies
import Domain
import Ergonomics
import Foundation
import Persistence
import PMLogger
import ProtonCorePaymentsV2
import StoreKit
import Strings
import VPNAppCore

#if os(iOS)
    import ProtonCorePaymentsUIV2
#endif

public protocol PaymentsPlanServiceV2: Sendable {
    var countryCode: String? { get async }
    var countriesCount: Int { get }
    var iapStatus: IAPSupportStatusV2 { get }
    var mostExpensivePlan: ComposedPlan? { get }

    var arePaymentsAllowed: Bool { get }

    func pushCantUpgradeAlert(
        localizedReason: String?,
        presentAlert: @escaping @Sendable (SystemAlert) -> Void
    )
    func fetchIAPStatus() async throws -> IAPSupportStatusV2
    func getAvailablePlans() async throws -> [ComposedPlan]
    func purchase(_ product: Product) async throws -> ComposedPlan?
    func presentSubscriptionManagement(
        presentAlert: @escaping @Sendable (SystemAlert) -> Void
    ) async
    func recoverTransaction() async throws
    func restorePurchase() async throws -> CurrentSubscriptionResponse
    func clear()
}

private final class IapCachedStatus: @unchecked Sendable {
    var iapSupportStatus: IAPSupportStatusV2 = .enabled
}

final class CorePaymentsPlanServiceV2: PaymentsPlanServiceV2, @unchecked Sendable {
    private var transactionSubscriptionCancellable: Cancellable?
    #if os(iOS)
        private var paymentsV2Cancellables: [AnyCancellable] = []
    #endif

    @Dependency(\.networking) private var networking
    #if os(iOS)
        @Dependency(\.authKeychain) private var authKeychain
    #endif

    private var remoteManager: RemoteManagerProviding
    private var plansComposer: PlansComposerProviding?
    private var observerStartTask: Task<Void, Error>?
    private var plansManagerReady: Task<PublicProtonPlansManagerProviding, Error>!
    #if os(iOS)
        private var paymentsV2: PaymentsV2?
    #endif
    private let iapCachedStatus: IapCachedStatus = .init()

    var countryCode: String? {
        get async {
            try? await plansManagerReady.value.countryCode
        }
    }

    var iapStatus: IAPSupportStatusV2 {
        iapCachedStatus.iapSupportStatus
    }

    var countriesCount: Int {
        @Dependency(\.serverRepository) var serverRepository
        return serverRepository.countryCount()
    }

    var mostExpensivePlan: ComposedPlan? {
        plansComposer?.mostExpensivePlan
    }

    var arePaymentsAllowed: Bool {
        if Bundle.isTestflight {
            return VPNFeatureFlagType.allowSandboxPurchases.enabled
        }
        return true
    }

    // MARK: - Init

    init() {
        @Dependency(\.networking) var networking
        self.remoteManager = RemoteManager(apiService: networking.apiService)

        let startTask = Task { [self] in
            try await createTransactionSubscription()
        }
        self.observerStartTask = startTask

        self.plansManagerReady = Task { [self] in
            do {
                try await startTask.value
                let plansComposer = PlansComposer(remoteManager: remoteManager)
                self.plansComposer = plansComposer
                return ProtonPlansManager(remoteManager: remoteManager, plansComposer: plansComposer)
            } catch {
                log.error("Error creating plan service: \(error)")
                throw error
            }
        }
    }

    func pushCantUpgradeAlert(
        localizedReason: String?,
        presentAlert: @escaping @Sendable (SystemAlert) -> Void
    ) {
        Task {
            @Dependency(\.sessionService) var sessionService

            guard let url = await sessionService.getPlanSession(mode: .upgrade) else {
                log.assertionFailure("Couldn't retrieve plan session URL")
                return
            }

            presentAlert(
                UpgradeUnavailableAlert(
                    message: localizedReason,
                    accountDashboardURL: url
                ) as SystemAlert
            )
        }
    }

    func fetchIAPStatus() async throws -> IAPSupportStatusV2 {
        try await ensureTransactionsObserverIsActive()
        _ = try await plansManagerReady.value
        let iapV6Response: IAPStatus = try await remoteManager.checkIAPStatus()
        iapCachedStatus.iapSupportStatus = iapV6Response.status
        return iapV6Response.status
    }

    func getAvailablePlans() async throws -> [ComposedPlan] {
        try await ensureTransactionsObserverIsActive()
        return try await plansManagerReady.value.getAvailablePlans()
    }

    func purchase(_ product: Product) async throws -> ComposedPlan? {
        try await ensureTransactionsObserverIsActive()
        return try await plansManagerReady.value.purchase(product, options: [])
    }

    func recoverTransaction() async throws {
        try await ensureTransactionsObserverIsActive()
        try await plansManagerReady.value.recoverTransactionReceipt()
    }

    func restorePurchase() async throws -> CurrentSubscriptionResponse {
        _ = try? await plansManagerReady.value

        #if os(iOS)
            guard let paymentsV2 else {
                log.error("Restoring purchase info requires login info", category: .iap)
                throw UnavailableError.noAuthDataPresent
            }

            return try await paymentsV2.restorePurchases(apiService: networking.apiService)
        #else
            throw UnavailableError.unsupportedPlatform
        #endif
    }

    func presentSubscriptionManagement(
        presentAlert: @escaping @Sendable (SystemAlert) -> Void
    ) async {
        #if os(iOS)
            guard arePaymentsAllowed else {
                pushCantUpgradeAlert(
                    localizedReason: Localizable.upgradeUnavailableOnTestflight,
                    presentAlert: presentAlert
                )
                return
            }

            if case let .disabled(localizedReason) = iapCachedStatus.iapSupportStatus {
                pushCantUpgradeAlert(
                    localizedReason: localizedReason,
                    presentAlert: presentAlert
                )
                return
            }

            do {
                try await ensureTransactionsObserverIsActive()
            } catch {
                log.error("Unable to activate payments transactions observer before presenting plans: \(error)", category: .iap)
                return
            }

            paymentsV2 = PaymentsV2()
            paymentsV2?.viewCycleState.sink { [weak self] state in
                self?.handlePaymentsV2ViewState(state: state)
            }.store(in: &paymentsV2Cancellables)

            Task { @MainActor in
                do {
                    try paymentsV2?.showAvailablePlans(
                        presentationMode: .modal,
                        hideCurrentPlan: authKeychain.fetch()?.isCredentialLess != false,
                        apiService: networking.apiService
                    )
                } catch {
                    log.error("No payment presentation mode provided")
                }
            }
        #else
            _ = presentAlert
        #endif
    }

    func clear() {
        observerStartTask = nil
        plansComposer = nil
        iapCachedStatus.iapSupportStatus = .enabled
        #if os(iOS)
            paymentsV2Cancellables.removeAll()
            paymentsV2 = nil
        #endif
        transactionSubscriptionCancellable = nil
        TransactionsObserver.shared.stop()
    }

    private func createTransactionSubscription() async throws {
        transactionSubscriptionCancellable = nil
        TransactionsObserver.shared.stop()

        let transactionsObserverConfiguration = TransactionsObserverConfiguration(remoteManager: remoteManager)
        TransactionsObserver.shared.setConfiguration(transactionsObserverConfiguration)

        try await TransactionsObserver.shared.start()
        transactionSubscriptionCancellable = TransactionsObserver.shared.transactionProgress.sink { [weak self] transactionProgress in
            self?.handleTransactionProgress(transactionProgress)
        }
    }

    #if os(iOS)
        private func handlePaymentsV2ViewState(state: ViewCycleState) {
            switch state {
            case .none:
                return
            case .displayed:
                return
            case .dismissed:
                paymentsV2Cancellables.removeAll()
                paymentsV2 = nil
            }
        }
    #endif

    /// `clear()` intentionally stops the observer on logout.
    /// The service instance survives logout/login, so we must restart it lazily before next usage.
    private func ensureTransactionsObserverIsActive() async throws {
        if TransactionsObserver.shared.isON {
            return
        }

        // Await in-flight start to avoid concurrent createTransactionSubscription() calls
        // racing on stop() + start() inside TransactionsObserver
        if let existingTask = observerStartTask {
            try await existingTask.value
            if TransactionsObserver.shared.isON { return }
        }

        // Observer was stopped (e.g. after logout) — create a fresh start task
        let task = Task { [self] in
            try await createTransactionSubscription()
        }
        observerStartTask = task
        try await task.value
    }

    private func handleTransactionProgress(_ transactionProgress: TransactionHandlerState) {
        switch transactionProgress {
        case .idle:
            break
        case .generatingReceipt:
            log.debug("Generating transaction receipt for iAP purchase", category: .iap)
        case .creatingTransactionToken:
            log.debug("Creating transaction token for iAP purchase", category: .iap)
        case .createNewSubscription:
            log.debug("Creating new subscription", category: .iap)
        case let .transactionCompleted(planName, cycle):
            log.debug("Purchased new plan", category: .iap)

            AppEvent.userDidCompletePurchase.post(
                PaymentTransactionFinishedEvent(
                    newPlanName: planName,
                    cycle: cycle,
                    offerReference: nil,
                    flowType: .oneClick
                )
            )
        case .transactionCancelledByUser:
            break
        case .mismatchTransactionIDs:
            log.error("Purchase failed due to mismatch transaction IDs", category: .iap)
        case .transactionProcessError:
            log.error("Purchase failed due to transaction process error", category: .iap)
        case .unableToGetUserTransactionUUID:
            log.error("Purchase failed due to unable to get user transaction UUID", category: .iap)
        case .unknownError:
            log.error("Purchase failed", category: .iap)
        case .waitingTokenResponse:
            log.debug("Waiting for token response", category: .iap)
        case .iapStatusCheck:
            log.debug("IAP status check", category: .iap)
        case .iapPurchase:
            log.debug("IAP purchase", category: .iap)
        case .fetchAvailablePlans:
            log.debug("Fetching available plans", category: .iap)
        case .fetchProtonPlans:
            log.debug("Fetching Proton plans", category: .iap)
        case .fetchUserUUID:
            log.debug("Fetching user UUID", category: .iap)
        case .transactionPending:
            log.debug("Transaction pending", category: .iap)
        case .transactionProcessErrorInvalidReq:
            log.error("Purchase failed due to invalid requirement in the transaction token", category: .iap)
        case .transactionTokenizationCompleted:
            log.debug("Transaction tokenization completed", category: .iap)
        }
    }
}

extension CorePaymentsPlanServiceV2 {
    enum UnavailableError: String, ProtonVPNError {
        static let errorDomain = "PlanServiceUnavailableErrorDomain"

        case noAuthDataPresent = "No authentication data was present."
        case unsupportedPlatform = "Operation is unsupported on this platform."

        var errorDescription: String? { rawValue }

        var charCode: FourCharCode {
            "P2NA"
        }
    }
}

private enum PlanServiceV2Key: DependencyKey {
    static let liveValue: any PaymentsPlanServiceV2 = CorePaymentsPlanServiceV2()
    static let testValue: any PaymentsPlanServiceV2 = UnimplementedPlanServiceV2()
}

private struct UnimplementedPlanServiceV2: PaymentsPlanServiceV2 {
    var countryCode: String? { get async { nil } }
    var countriesCount: Int { 0 }
    var iapStatus: IAPSupportStatusV2 { .enabled }
    var mostExpensivePlan: ComposedPlan? { nil }
    var arePaymentsAllowed: Bool { true }
    func pushCantUpgradeAlert(
        localizedReason _: String?,
        presentAlert _: @escaping @Sendable (SystemAlert) -> Void
    ) {}
    func fetchIAPStatus() async throws -> IAPSupportStatusV2 { .enabled }
    func getAvailablePlans() async throws -> [ComposedPlan] { [] }
    func purchase(_: Product) async throws -> ComposedPlan? { nil }
    func presentSubscriptionManagement(
        presentAlert _: @escaping @Sendable (SystemAlert) -> Void
    ) async {}
    func recoverTransaction() async throws {}
    func restorePurchase() async throws -> CurrentSubscriptionResponse { throw UnimplementedError() }
    func clear() {}
}

private struct UnimplementedError: Error {}

public extension DependencyValues {
    var paymentsPlanServiceV2: any PaymentsPlanServiceV2 {
        get { self[PlanServiceV2Key.self] }
        set { self[PlanServiceV2Key.self] = newValue }
    }
}
