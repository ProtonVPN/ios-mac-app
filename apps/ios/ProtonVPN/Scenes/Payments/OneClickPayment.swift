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

import Foundation

import Domain
import Modals
import Modals_iOS

import ProtonCoreFeatureFlags
import ProtonCorePayments

class OneClickPayment {
    typealias Factory = WindowServiceFactory & PlanServiceFactory

    private let windowService: WindowService
    private let planService: PlanService
    private var completionHandler: (() -> Void)?

    var unfinishedPurchasePlan: InAppPurchasePlan?

    init(factory: Factory) {
        windowService = factory.makeWindowService()
        planService = factory.makePlanService()
    }

    func presentOneClickIAP(completionHandler: @escaping () -> Void) throws {
        guard FeatureFlagsRepository.shared.isEnabled(VPNFeatureFlagType.oneClickPayment),
              let plansDataSource = planService.plansDataSource else {
            throw "OneClickAIAP or DynamicPlan FF disabled!"
        }
        self.completionHandler = completionHandler
        let subscriptionViewController = ModalsFactory().subscriptionViewController(plansClient: plansClient(plansDataSource))
        windowService.addToStack(subscriptionViewController, checkForDuplicates: false)
    }

    private func plansClient(_ plansDataSource: PlansDataSourceProtocol) -> PlansClient {
        PlansClient(retrievePlans: { [weak self] in
            guard let self else { throw "Onboarding was dismissed" }
            return try await self.planService.planOptions(with: plansDataSource)
        }, validate: { [weak self] in
            await self?.validate(selectedPlan: $0)
        }, notNow: { [weak self] in
            self?.completionHandler?()
        })
    }

    @MainActor
    func validate(selectedPlan: PlanOption) async -> Void {
        guard unfinishedPurchasePlan == nil else {
            // purchase already started, don't start it again, report back that we're in progress
//            finishCallback(.planPurchaseProcessingInProgress(processingPlan: unfinishedPurchasePlan!))
            completionHandler?()
            return
        }
        let result = await self.planService.buyPlan(planOption: selectedPlan)
        await self.buyPlanResultHandler(result)
    }

    @MainActor
    private func buyPlanResultHandler(_ result: PurchaseResult) async {
        switch result {
        case .purchasedPlan(let plan):
            unfinishedPurchasePlan = nil
            await planService.delegate?.paymentTransactionDidFinish(modalSource: nil,
                                                                    newPlanName: plan.protonName)
            completionHandler?()
        case .toppedUpCredits:
            print("pj toppedUpCredits")
            assertionFailure("This flow only supports subscriptions, got `toppedUpCredits` result")
            break
        case .planPurchaseProcessingInProgress(let processingPlan):
            // TODO: VPNAPPL-2089 should we do anything?
            // Should we allow the user to close the modal before the transaction is finished?
            // It will be easier if we won't
            print("pj planPurchaseProcessingInProgress")
            unfinishedPurchasePlan = processingPlan
        case let .purchaseError(error, processingPlan):
            print("pj purchaseError")
            // TODO: VPNAPPL-2089 present the error to the user and stay at the screen
            unfinishedPurchasePlan = nil
            break
        case let .apiMightBeBlocked(message, originalError, processingPlan):
            print("pj apiMightBeBlocked")
            // TODO: VPNAPPL-2089 present the error to the user with alert service
            unfinishedPurchasePlan = processingPlan
            break
        case .purchaseCancelled:
            // show alert "transaction cancelled"
            print("pj purchaseCancelled")
            unfinishedPurchasePlan = nil
            break
        }
    }
}
