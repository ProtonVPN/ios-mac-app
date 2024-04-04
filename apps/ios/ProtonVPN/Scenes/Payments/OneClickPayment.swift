//
//  Created on 04/04/2024.
//
//  Copyright (c) 2024 Proton AG
//
//  ProtonVPN is free software: you can redistribute it and/or modify
//  it under the terms of the GNU General Public License as published by
//  the Free Software Foundation, either version 3 of the License, or
//  (at your option) any later version.
//
//  ProtonVPN is distributed in the hope that it will be useful,
//  but WITHOUT ANY WARRANTY; without even the implied warranty of
//  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
//  GNU General Public License for more details.
//
//  You should have received a copy of the GNU General Public License
//  along with ProtonVPN.  If not, see <https://www.gnu.org/licenses/>.

import UIKit

import Domain
import Modals
import Modals_iOS
import LegacyCommon

import ProtonCoreFeatureFlags
import ProtonCorePayments

class OneClickPayment {
    typealias Factory = PlanServiceFactory & CoreAlertServiceFactory

    private let alertService: CoreAlertService
    private let planService: PlanService
    private let payments: Payments
    private var completionHandler: (() -> Void)?

    init(factory: Factory, payments: Payments) {
        planService = factory.makePlanService()
        alertService = factory.makeCoreAlertService()
        self.payments = payments
    }

    func presentOneClickIAP(completionHandler: @escaping () -> Void) throws -> UIViewController {
        guard FeatureFlagsRepository.shared.isEnabled(VPNFeatureFlagType.oneClickPayment),
              let plansDataSource else {
            throw "OneClickAIAP or DynamicPlan FF disabled!"
        }
        self.completionHandler = completionHandler
        return ModalsFactory().subscriptionViewController(plansClient: plansClient(plansDataSource))
    }

    private func plansClient(_ plansDataSource: PlansDataSourceProtocol) -> PlansClient {
        PlansClient(retrievePlans: { [weak self] in
            guard let self else { throw "Onboarding was dismissed" }
            return try await self.planOptions(with: plansDataSource)
        }, validate: { [weak self] in
            await self?.validate(selectedPlan: $0)
        }, notNow: { [weak self] in
            self?.completionHandler?()
        })
    }

    @MainActor
    func validate(selectedPlan: PlanOption) async -> Void {
        let result = await self.buyPlan(planOption: selectedPlan)
        await self.buyPlanResultHandler(result)
    }

    @MainActor
    private func buyPlanResultHandler(_ result: PurchaseResult) async {
        switch result {
        case .purchasedPlan(let plan):
            log.debug("Purchased plan: \(plan.protonName)", category: .iap)
            await planService.delegate?.paymentTransactionDidFinish(modalSource: nil,
                                                                    newPlanName: plan.protonName)
            completionHandler?()
        case .toppedUpCredits:
            assertionFailure("This flow only supports subscriptions, got `toppedUpCredits` result")
            break
        case .planPurchaseProcessingInProgress(let plan):
            log.debug("Purchasing \(plan.protonName)", category: .iap)
            alertService.push(alert: PaymentAlert(message: "Processing plan purchase in progress...", isError: false))
            break
        case let .purchaseError(error, _):
            log.error("Purchase failed", category: .iap, metadata: ["error": "\(error)"])
            alertService.push(alert: PaymentAlert(message: error.localizedDescription, isError: true))
            break
        case let .apiMightBeBlocked(message, originalError, _):
            log.error("\(message)", category: .connection, metadata: ["error": "\(originalError)"])
            alertService.push(alert: PaymentAlert(message: message, isError: true))
            break
        case .purchaseCancelled:
            break
        }
    }

    var inAppPurchasePlans: [(PlanOption, InAppPurchasePlan)] = []

    func planOptions(with plansDataSource: PlansDataSourceProtocol) async throws -> [PlanOption] {
        try await plansDataSource.fetchAvailablePlans()
        let vpn2022 = plansDataSource.availablePlans?.plans.filter { plan in
            plan.name == "vpn2022"
        }.first // it's only going to be one with this plan name
        guard let vpn2022 else { throw "Default plan not found" }
        inAppPurchasePlans = vpn2022.instances
            .compactMap { InAppPurchasePlan(availablePlanInstance: $0) }
            .compactMap { iAP -> (PlanOption, InAppPurchasePlan)? in
                guard let priceLabel = iAP.priceLabel(from: payments.storeKitManager),
                      let period = iAP.period else { return nil }
                let planOption = PlanOption(duration: .init(components: .init(month: Int(period))),
                                            price: .init(amount: priceLabel.value.doubleValue,
                                                         currency: iAP.currency ?? "",
                                                         locale: priceLabel.locale))
                return (planOption, iAP)
            }
        return inAppPurchasePlans.map { $0.0 }
    }

    func buyPlan(planOption: PlanOption) async -> PurchaseResult {
        guard !payments.storeKitManager.hasUnfinishedPurchase() else {
            log.debug("StoreKitManager is not ready to purchase", category: .userPlan)
            return .purchaseError(error: "StoreKitManager is not ready to purchase", processingPlan: nil)
        }
        let plan = inAppPurchasePlans.first { plan, _ in
            plan.fingerprint == planOption.fingerprint
        }
        guard let iAP = plan?.1 else {
            return .purchaseError(error: "StoreKitManager plan not found", processingPlan: nil)
        }
        return await withCheckedContinuation {
            payments.purchaseManager.buyPlan(plan: iAP,
                                             finishCallback: $0.resume(returning:))
        }
    }

    var plansDataSource: PlansDataSourceProtocol? {
        guard case .right(let plansDataSource) = payments.planService else {
            return nil
        }
        return plansDataSource
    }
}
