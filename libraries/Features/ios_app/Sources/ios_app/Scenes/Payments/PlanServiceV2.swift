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
import ProtonCorePaymentsUIV2
import ProtonCorePaymentsV2
import StoreKit
import Strings
import Telemetry
import VPNAppCore
import VPNShared

struct PaymentTransactionFinishedEvent: Sendable {
    let modalSource: UpsellModalSource?
    let newPlanName: String?
    let offerReference: String?
    let flowType: UpsellEvent.FlowType?

    static let webIntroFinishEvent: PaymentTransactionFinishedEvent = .init(
        modalSource: nil,
        newPlanName: "vpn2024", // TODO: update it to be dynamic https://protonag.atlassian.net/browse/VPNAPPL-3103
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
    private var authCredentialsChangedCancellable: Cancellable?
    private var transactionSubscriptionCancellable: Cancellable?
    private var paymentsV2Cancellables: [AnyCancellable] = []

    @Dependency(\.dohConfiguration) private var doh
    @Dependency(\.authKeychain) private var authKeychain

    private lazy var paymentsAPIs = PaymentsAPIs(doh: doh)
    private var remoteManager: RemoteManagerProviding?
    private var plansComposer: PlansComposerProviding?
    private var protonPlansManager: PublicProtonPlansManagerProviding?
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
            await protonPlansManager?.countryCode
        }
    }

    @Dependency(\.appInfo) private var appInfo

    // MARK: - Init

    init() {
        // initial setup; will create managers if auth credentials are present
        let authCredentials: AuthCredentials? = authKeychain.fetch()
        self.logoutObservation = AppEvent.userDidLogOut.subscribe { [weak self] _ in
            self?.clear()
        }

        Task { [weak self] in
            do {
                try await self?.recreateTransactionSubscription(authCredentials: authCredentials)
                self?.createPaymentsManagers(authCredentials: authCredentials)

                // setup subscription to react to auth credentials change
                self?.authCredentialsChangedCancellable = AppEvent.authCredentialsChanged.publisher
                    .sink { [weak self] _ in
                        self?.handleAuthCredentialsChanged()
                    }
            } catch {
                log.error("Error creating plan service: \(error)")
            }
        }
    }

    deinit {
        NotificationCenter.default.removeObserver(logoutObservation as Any)
    }

    private func createPaymentsManagers(authCredentials: AuthCredentials?) {
        guard let authCredentials else {
            log.info("No auth credentials to create payment managers", category: .iap)
            return clear()
        }

        let remoteManager = RemoteManager(
            sessionID: authCredentials.sessionId,
            authToken: authCredentials.accessToken,
            appVersion: appInfo.appVersion,
            atlasSecret: doh.atlasSecret
        )
        self.remoteManager = remoteManager
        let plansComposer = PlansComposer(remoteManager: remoteManager, paymentsAPIs: paymentsAPIs)
        self.plansComposer = plansComposer
        let protonPlansManager = ProtonPlansManager(doh: doh, remoteManager: remoteManager, plansComposer: plansComposer)
        self.protonPlansManager = protonPlansManager
    }

    private func handleAuthCredentialsChanged() {
        guard let authCredentials = authKeychain.fetch() else {
            log.info("No auth credentials to create payment managers", category: .iap)
            return clear()
        }
        updateRemoteManager(authCredentials: authCredentials)

        Task {
            do {
                try await recreateTransactionSubscription(authCredentials: authCredentials)
            } catch {
                log.error("Could not recreate transaction subscription: \(error)")
            }
        }
    }

    private func updateRemoteManager(authCredentials: AuthCredentials?) {
        guard remoteManager != nil else {
            return createPaymentsManagers(authCredentials: authCredentials)
        }
        guard let authCredentials else {
            log.info("No auth credentials to update payment managers", category: .iap)
            return clear()
        }
        remoteManager?.updateSession(sessionID: authCredentials.sessionId, authToken: authCredentials.accessToken)
    }

    private func recreateTransactionSubscription(authCredentials: AuthCredentials?) async throws {
        guard let authCredentials else {
            log.info("No auth credentials to subscribe to transactions", category: .iap)
            return clear()
        }
        // unsubscribe from previous subscriptions
        transactionSubscriptionCancellable = nil
        TransactionsObserver.shared.stop()

        let transactionsObserverConfiguration = TransactionsObserverConfiguration(
            sessionID: authCredentials.sessionId,
            authToken: authCredentials.accessToken,
            appVersion: appInfo.appVersion,
            doh: doh
        )
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
        remoteManager = nil
        plansComposer = nil
        protonPlansManager = nil
        iapCachedStatus.clear()
        transactionSubscriptionCancellable = nil
        TransactionsObserver.shared.stop()
    }

    func fetchAppleStatus() async throws {
        let iapStatusRequest = try paymentsAPIs.url(for: .appleStatus)
        let iapV6Response: IAPStatus? = try await remoteManager?.getFromURL(iapStatusRequest.url)
        // if no remoteManager is present then we're in incorrect state => iAP disabled
        iapCachedStatus.iapSupportStatus = iapV6Response?.status ?? .disabled(localizedReason: nil)
    }

    func getAvailablePlans() async throws -> [ComposedPlan] {
        guard let protonPlansManager else { throw UnavailableError.noAuthDataPresent }
        return try await protonPlansManager.getAvailablePlans()
    }

    func purchase(_ product: Product) async throws -> ComposedPlan? {
        guard let protonPlansManager else {
            throw UnavailableError.noAuthDataPresent
        }
        return try await protonPlansManager.purchase(product, options: [])
    }

    func recoverTransaction() async throws {
        guard let protonPlansManager else {
            throw UnavailableError.noAuthDataPresent
        }
        try await protonPlansManager.recoverTransactionReceipt()
    }

    func restorePurchase() async throws -> CurrentSubscriptionResponse {
        guard let paymentsV2, let authCredentials = authKeychain.fetch() else {
            // no login info present
            log.error("Restoring purchase info requires login info", category: .iap)
            throw UnavailableError.noAuthDataPresent
        }

        return try await paymentsV2.restorePurchases(
            sessionId: authCredentials.sessionId,
            token: authCredentials.accessToken,
            doh: doh,
            appVersion: appInfo.appVersion
        )
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
        guard let authCredentials = authKeychain.fetch() else {
            // no login info present
            log.error("Presenting subscription management requires login info", category: .iap)
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
                    sessionID: authCredentials.sessionId,
                    accessToken: authCredentials.accessToken,
                    appVersion: appInfo.appVersion,
                    doh: doh
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
        case .transactionCompleted:
            log.debug("Purchased new plan", category: .iap)
            AppEvent.userDidCompletePurchase.post(
                PaymentTransactionFinishedEvent(
                    modalSource: nil,
                    newPlanName: nil,
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
