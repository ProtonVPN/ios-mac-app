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

import Foundation
import Dependencies
import Combine
import CommonNetworking
import ProtonCorePaymentsV2
import ProtonCorePaymentsUIV2
import LegacyCommon
import VPNAppCore
import VPNShared

protocol PlanServiceFactoryV2 {
    func makePlanServiceV2() -> PlanServiceV2?
}

protocol PlanServiceDelegate: AnyObject {
    @MainActor
    func paymentTransactionDidFinish(modalSource: UpsellModalSource?, newPlanName: String?) async
}

protocol PlanServiceV2 {
    var delegate: PlanServiceDelegate? { get set }
    var protonPlansManager: ProtonPlansManagerProviding { get }
    var plansComposer: PlansComposerProviding { get }

    func presentSubscriptionManagement() async
}

final class CorePlanServiceV2: PlanServiceV2 {
    @Dependency(\.serverRepository) var serverRepository

    var cancellables: [AnyCancellable] = []

    let plansComposer: PlansComposerProviding
    let protonPlansManager: ProtonPlansManagerProviding

    private let alertService: CoreAlertService
    private let authKeychain: AuthKeychainHandle

    var countriesCount: Int {
        serverRepository.countryCount()
    }

    weak var delegate: PlanServiceDelegate?

    /// V6PaymentStatusResponse from v6/status/apple
//    var iapStatus: IAPSupportStatus {
//        return userCachedStatus.iapSupportStatus
//    }

    // MARK: - Init

    init?(networking: Networking, alertService: CoreAlertService, authKeychain: AuthKeychainHandle) {
        guard let authCredentials = authKeychain.fetch() else {
            return nil
        }

        self.alertService = alertService
        self.authKeychain = authKeychain

        @Dependency(\.dohConfiguration) var doh
        let appInfo = AppInfoImplementation(context: .mainApp)

        let remoteManager = RemoteManager(
            sessionID: authCredentials.sessionId,
            authToken: authCredentials.accessToken,
            appVersion: appInfo.appVersion
        )
        let plansComposer = PlansComposer(remoteManager: remoteManager, paymentsAPIs: .init(doh: doh))
        self.protonPlansManager = ProtonPlansManager(doh: doh, remoteManager: remoteManager, plansComposer: plansComposer)
        self.plansComposer = plansComposer

        self.protonPlansManager.transactionProgress.sink { [weak self] transactionProgress in
            self?.handleTransactionProgress(transactionProgress)
        }.store(in: &cancellables)
    }

    func presentSubscriptionManagement() async {
//        if case let .disabled(localizedReason) = iapSupportStatus {
//            alertService.push(alert: UpgradeUnavailableAlert(message: localizedReason))
//            return
//        }
        guard let authCredentials = authKeychain.fetch() else {
            return
        }

        @Dependency(\.dohConfiguration) var doh
        let appInfo = AppInfoImplementation(context: .mainApp)

        let transactionsObserverConfiguration = TransactionsObserverConfiguration(
            sessionID: authCredentials.sessionId,
            authToken: authCredentials.accessToken,
            appVersion: appInfo.appVersion,
            doh: doh
        )
        TransactionsObserver.shared.setConfiguration(transactionsObserverConfiguration)
        try? await TransactionsObserver.shared.start()

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
                await self?.delegate?.paymentTransactionDidFinish(modalSource: nil, newPlanName: nil)
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
