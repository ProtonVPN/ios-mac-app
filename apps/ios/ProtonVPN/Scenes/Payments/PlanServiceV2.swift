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
import CommonNetworking
import ProtonCorePaymentsV2
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
}

final class CorePlanServiceV2: PlanServiceV2 {
    @Dependency(\.serverRepository) var serverRepository

    let plansComposer: PlansComposerProviding
    let protonPlansManager: ProtonPlansManagerProviding

    var countriesCount: Int {
        serverRepository.countryCount()
    }

    weak var delegate: PlanServiceDelegate?

    /// V6PaymentStatusResponse from v6/status/apple
//    var iapStatus: IAPSupportStatus {
//        return userCachedStatus.iapSupportStatus
//    }

    var mostExpensivePlan: ComposedPlan? {
        plansComposer.mostExpensivePlan
    }

    init?(networking: Networking, authKeychain: AuthKeychainHandle) {
        guard let authCredentials = authKeychain.fetch() else {
            return nil
        }

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
    }

//    private func handlePaymentsResponse(response: PaymentsUIResultReason, modalSource: UpsellModalSource?) {
//        switch response {
//        case .planAlreadyPurchased(let error):
//            log.error("Plan already purchased", category: .connection, metadata: ["error": "\(error)"])
//        case let .purchasedPlan(accountPlan: plan):
//            log.debug("Purchased plan: \(plan.protonName)", category: .iap)
//            Task { [weak self] in
//                await self?.delegate?.paymentTransactionDidFinish(modalSource: modalSource, newPlanName: plan.protonName)
//            }
//        case let .open(vc: _, opened: opened):
//            assert(opened == true)
//        case let .planPurchaseProcessingInProgress(accountPlan: plan):
//            log.debug("Purchasing \(plan.protonName)", category: .iap)
//        case .close:
//            log.debug("Payments closed", category: .iap)
//        case let .purchaseError(error: error):
//            log.error("Purchase failed", category: .iap, metadata: ["error": "\(error)"])
//        case .toppedUpCredits:
//            log.debug("Credits topped up", category: .iap)
//        case let .apiMightBeBlocked(message, originalError: error):
//            log.error("\(message)", category: .connection, metadata: ["error": "\(error)"])
//        }
//    }
}
