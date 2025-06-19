//
//  Created on 22/05/2025 by Max Kupetskyi.
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
import Foundation
import LegacyCommon
import ProtonCorePaymentsUIV2
import ProtonCorePaymentsV2
import VPNAppCore
import VPNShared

protocol PlanServiceFactory {
    func makePlanService() -> PlanService?
}

protocol PlanServiceDelegate: AnyObject {
    @MainActor
    func paymentTransactionDidFinish(modalSource: UpsellModalSource?, newPlanName: String?, offerReference: String?, flowType: UpsellEvent.FlowType?) async
}

protocol PlanService {
    var delegate: PlanServiceDelegate? { get set }
    var protonPlansManager: ProtonPlansManagerProviding { get }
    var plansComposer: PlansComposerProviding { get }
    var countriesCount: Int { get }
    var iapStatus: IAPSupportStatusV2 { get }

    func presentSubscriptionManagement() async
    func fetchAppleStatus() async throws
    func clear()
}

final class CorePlanService: PlanService {
    @Dependency(\.serverRepository) var serverRepository

    private var cancellables: [AnyCancellable] = []

    let remoteManager: RemoteManagerProviding
    let paymentsAPIs: PaymentsAPIs
    let plansComposer: PlansComposerProviding
    let protonPlansManager: ProtonPlansManagerProviding

    private let alertService: CoreAlertService
    private let authKeychain: AuthKeychainHandle
    private let iapCachedStatus: IapCachedStatus

    var countriesCount: Int {
        serverRepository.countryCount()
    }

    weak var delegate: PlanServiceDelegate?

    /// V6PaymentStatusResponse from v6/status/apple
    var iapStatus: IAPSupportStatusV2 {
        iapCachedStatus.iapSupportStatus
    }

    // MARK: - Init

    init?(alertService: CoreAlertService, authKeychain: AuthKeychainHandle) {
        guard let authCredentials = authKeychain.fetch() else {
            return nil
        }

        self.alertService = alertService
        self.authKeychain = authKeychain
        self.iapCachedStatus = IapCachedStatus()

        @Dependency(\.dohConfiguration) var doh
        let appInfo = AppInfoImplementation(context: .mainApp)

        let remoteManager = RemoteManager(
            sessionID: authCredentials.sessionId,
            authToken: authCredentials.accessToken,
            appVersion: appInfo.appVersion,
            atlasSecret: doh.atlasSecret
        )
        self.remoteManager = remoteManager
        let paymentsAPIs = PaymentsAPIs(doh: doh)
        self.paymentsAPIs = paymentsAPIs
        let plansComposer = PlansComposer(remoteManager: remoteManager, paymentsAPIs: paymentsAPIs)
        self.protonPlansManager = ProtonPlansManager(doh: doh, remoteManager: remoteManager, plansComposer: plansComposer)
        self.plansComposer = plansComposer

        let transactionsObserverConfiguration = TransactionsObserverConfiguration(
            sessionID: authCredentials.sessionId,
            authToken: authCredentials.accessToken,
            appVersion: appInfo.appVersion,
            doh: doh
        )
        TransactionsObserver.shared.setConfiguration(transactionsObserverConfiguration)
        Task {
            try? await TransactionsObserver.shared.start()
        }

        protonPlansManager.transactionProgress.sink { [weak self] transactionProgress in
            self?.handleTransactionProgress(transactionProgress)
        }.store(in: &cancellables)
    }

    func clear() {
        iapCachedStatus.clear()
    }

    func fetchAppleStatus() async throws {
        let iapStatusRequest = try paymentsAPIs.url(for: .appleStatus)
        let iapV6Response: IAPStatus = try await remoteManager.getFromURL(iapStatusRequest.url)
        iapCachedStatus.iapSupportStatus = iapV6Response.status
    }

    func presentSubscriptionManagement() async {
        if case let .disabled(localizedReason) = iapCachedStatus.iapSupportStatus {
            alertService.push(alert: UpgradeUnavailableAlert(message: localizedReason))
            return
        }
        guard let authCredentials = authKeychain.fetch() else {
            return
        }

        @Dependency(\.dohConfiguration) var doh
        let appInfo = AppInfoImplementation(context: .mainApp)

        Task { @MainActor in
            // can only throw if no presentationMode is provided
            try? PaymentsV2().showAvailablePlans(
                presentationMode: .modal,
                sessionID: authCredentials.sessionId,
                accessToken: authCredentials.accessToken,
                appVersion: appInfo.appVersion,
                doh: doh
            )
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
            Task { [weak self] in
                await self?.delegate?
                    .paymentTransactionDidFinish(
                        modalSource: nil,
                        newPlanName: nil,
                        offerReference: nil,
                        flowType: .oneClick
                    )
            }
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
        }
    }
}
