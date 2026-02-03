//
//  Created on 07/07/2025 by Max Kupetskyi.
//
//  Copyright (c) 2025 Proton AG
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
import Dependencies
import Domain
import Foundation
import LegacyCommon
import Modals
import ProtonCorePaymentsUIV2
import ProtonCorePaymentsV2
import StoreKit
import Strings
import Telemetry
import VPNAppCore
import VPNShared

struct PaymentTransactionFinishedEvent: Sendable {
    let newPlanName: String?
    let cycle: Int?
    let offerReference: String?
    let flowType: UpsellEvent.FlowType?

    static let webIntroFinishEvent: PaymentTransactionFinishedEvent = .init(
        newPlanName: "vpn2024", // TODO: update it to be dynamic https://protonag.atlassian.net/browse/VPNAPPL-3103
        cycle: PlanOption.twoYearsWebPlan.duration.months,
        offerReference: "VPNINTROPRICE2024",
        flowType: .external
    )
}

protocol PlanServiceV2 {
    var mostExpensivePlan: ComposedPlan? { get }
    var countryCode: String? { get async }
    var countriesCount: Int { get }
    var iapStatus: IAPSupportStatusV2 { get }

    func getAvailablePlans() async throws -> [ComposedPlan]
    func purchase(_ product: Product) async throws -> ComposedPlan?
    func presentSubscriptionManagement(alertService: CoreAlertService) async
    func fetchAppleStatus() async throws
    func recoverTransaction() async throws
    func restorePurchase() async throws -> CurrentSubscriptionResponse
    func clear()
}

extension PlanServiceV2 {
    var arePaymentsAllowed: Bool {
        if Bundle.isTestflight {
            if VPNFeatureFlagType.allowSandboxPurchases.enabled {
                log.info("Allowing Sandbox purchases (feature flag enabled)")
                return true
            } else {
                log.info("Disabling Sandbox purchases (feature flag disabled)")
                return false
            }
        }
        log.info("Allowing payments (not on TestFlight)")
        return true
    }

    func pushCantUpgradeAlert(alertService: CoreAlertService, localizedReason: String?) {
        Task {
            @Dependency(\.sessionService) var sessionService

            // Fetch a session login URL so the user can easily visit their account page.
            guard let url = await sessionService.getPlanSession(mode: .upgrade) else {
                log.assertionFailure("Couldn't retrieve plan session URL")
                return
            }
            alertService.push(
                alert: UpgradeUnavailableAlert(
                    message: localizedReason,
                    accountDashboardURL: url
                )
            )
        }
    }
}

final class CorePlanServiceV2: PlanServiceV2, Sendable {
    private var transactionSubscriptionCancellable: Cancellable?
    private var paymentsV2Cancellables: [AnyCancellable] = []

    @Dependency(\.networking) private var networking

    private var remoteManager: RemoteManagerProviding
    private var plansComposer: PlansComposerProviding?
    private var plansManagerReady: Task<PublicProtonPlansManagerProviding, Error>!
    private var logoutObservation: NSObjectProtocol!

    private var paymentsV2: PaymentsV2?

    private let iapCachedStatus: IapCachedStatus = .init()

    var countriesCount: Int {
        @Dependency(\.serverRepository) var serverRepository
        return serverRepository.countryCount()
    }

    /// V6PaymentStatusResponse from v6/status/apple
    var iapStatus: IAPSupportStatusV2 {
        iapCachedStatus.iapSupportStatus
    }

    var mostExpensivePlan: ComposedPlan? {
        plansComposer?.mostExpensivePlan
    }

    var countryCode: String? {
        get async {
            try? await plansManagerReady.value.countryCode
        }
    }

    // MARK: - Init

    init() {
        @Dependency(\.networking) var networking
        self.remoteManager = RemoteManager(apiService: networking.apiService)
        self.logoutObservation = AppEvent.userDidLogOut.subscribe { [weak self] _ in
            self?.clear()
        }

        self.plansManagerReady = Task {
            do {
                try await createTransactionSubscription()

                let plansComposer = PlansComposer(remoteManager: remoteManager)
                self.plansComposer = plansComposer
                let protonPlansManager = ProtonPlansManager(remoteManager: remoteManager, plansComposer: plansComposer)
                return protonPlansManager
            } catch {
                log.error("Error creating plan service: \(error)")
                throw error
            }
        }
    }

    deinit {
        NotificationCenter.default.removeObserver(logoutObservation as Any)
    }

    private func createTransactionSubscription() async throws {
        // unsubscribe from previous subscriptions
        transactionSubscriptionCancellable = nil
        TransactionsObserver.shared.stop()

        let transactionsObserverConfiguration = TransactionsObserverConfiguration(remoteManager: remoteManager)
        TransactionsObserver.shared.setConfiguration(transactionsObserverConfiguration)

        do {
            try await TransactionsObserver.shared.start()

            transactionSubscriptionCancellable = TransactionsObserver.shared.transactionProgress.sink { [weak self] transactionProgress in
                self?.handleTransactionProgress(transactionProgress)
            }
        } catch {
            log.warning("Can't start payments transactions observer: \(error)", category: .iap)
        }
    }

    func clear() {
        plansComposer = nil
        iapCachedStatus.clear()
        transactionSubscriptionCancellable = nil
        TransactionsObserver.shared.stop()
    }

    func fetchAppleStatus() async throws {
        let iapV6Response: IAPStatus = try await remoteManager.checkIAPStatus()
        iapCachedStatus.iapSupportStatus = iapV6Response.status
    }

    func getAvailablePlans() async throws -> [ComposedPlan] {
        try await plansManagerReady.value.getAvailablePlans()
    }

    func purchase(_ product: Product) async throws -> ComposedPlan? {
        try await plansManagerReady.value.purchase(product, options: [])
    }

    func recoverTransaction() async throws {
        try await plansManagerReady.value.recoverTransactionReceipt()
    }

    func restorePurchase() async throws -> CurrentSubscriptionResponse {
        _ = try? await plansManagerReady.value

        guard let paymentsV2 else {
            // no login info present
            log.error("Restoring purchase info requires login info", category: .iap)
            throw UnavailableError.noAuthDataPresent
        }

        return try await paymentsV2.restorePurchases(apiService: networking.apiService)
    }

    func presentSubscriptionManagement(alertService: CoreAlertService) async {
        guard arePaymentsAllowed else {
            pushCantUpgradeAlert(
                alertService: alertService,
                localizedReason: Localizable.upgradeUnavailableOnTestflight
            )
            return
        }

        if case let .disabled(localizedReason) = iapCachedStatus.iapSupportStatus {
            pushCantUpgradeAlert(alertService: alertService, localizedReason: localizedReason)
            return
        }

        paymentsV2 = PaymentsV2()
        paymentsV2?.viewCycleState.sink { [weak self] paymentsV2ViewState in
            self?.handlePaymentsV2ViewState(state: paymentsV2ViewState)
        }.store(in: &paymentsV2Cancellables)

        // can only throw if no presentationMode is provided
        Task { @MainActor in
            do {
                try paymentsV2?.showAvailablePlans(
                    presentationMode: .modal,
                    apiService: networking.apiService
                )
            } catch {
                log.error("No payment presentation mode provided")
            }
        }
    }

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

extension CorePlanServiceV2 {
    enum UnavailableError: String, ProtonVPNError {
        public static let errorDomain = "PlanServiceUnavailableErrorDomain"

        case noAuthDataPresent = "No authentication data was present."

        var errorDescription: String? { rawValue }

        var charCode: FourCharCode {
            "P2NA"
        }
    }
}

extension ProtonPlansManagerError: @retroactive ProtonVPNError {
    public static let errorDomain = "ProtonPlansManagerErrorDomain"

    public var charCode: FourCharCode {
        switch self {
        case .unableToMatchProtonPlanToStoreProduct:
            "P2SP"
        case .unableToGetUserTransactionUUID:
            "P2TU"
        case .unableToRestorePurchases:
            "P2RP"
        case .iapNotAvailable:
            "P2XI"
        case .noOfferFound:
            "P2NO"
        case .iOSVersionError:
            "P2VE"
        case .transactionCancelledByUser:
            "P2TC"
        case .transactionUnknownError:
            "P2UE"
        case .noUnfinshedTransactionsFound:
            "P2NU"
        }
    }
}

// MARK: - Dependencies

private enum PlanServiceKey: DependencyKey {
    static let liveValue: PlanServiceV2 = CorePlanServiceV2()
    static let testValue: PlanServiceV2 = CorePlanServiceV2()
}

extension DependencyValues {
    var planServiceV2: PlanServiceV2 {
        get { self[PlanServiceKey.self] }
        set { self[PlanServiceKey.self] = newValue }
    }
}
