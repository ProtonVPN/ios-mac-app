//
//  Created on 05.01.2022.
//
//  Copyright (c) 2022 Proton AG
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
import UIKit
import Domain
import LegacyCommon
import LocalFeatureFlags
import VPNShared
import Modals
import Modals_iOS
import ProtonCoreFeatureFlags
import ProtonCorePayments

protocol OnboardingServiceFactory: AnyObject {
    func makeOnboardingService() -> OnboardingService
}

protocol OnboardingServiceDelegate: AnyObject {
    func onboardingServiceDidFinish()
}

protocol OnboardingService: AnyObject {
    var delegate: OnboardingServiceDelegate? { get set }

    func showOnboarding()
}

final class OnboardingModuleService {
    typealias Factory = WindowServiceFactory & PlanServiceFactory

    private let windowService: WindowService
    private let planService: PlanService

    weak var delegate: OnboardingServiceDelegate?

    init(factory: Factory) {
        windowService = factory.makeWindowService()
        planService = factory.makePlanService()
    }
}

extension OnboardingModuleService: OnboardingService {
    func showOnboarding() {
        log.debug("Starting onboarding", category: .app)
        let navigationController = UINavigationController(rootViewController: welcomeToProtonViewController())
        navigationController.setNavigationBarHidden(true, animated: false)
        windowService.show(viewController: navigationController)
    }

    private func welcomeToProtonViewController() -> UIViewController {
        ModalsFactory().modalViewController(modalType: .welcomeToProton, primaryAction: { [weak self] in
            self?.presentUpsell()
        })
    }

    func presentUpsell() {
        guard FeatureFlagsRepository.shared.isEnabled(VPNFeatureFlagType.oneClickPayment),
              FeatureFlagsRepository.shared.isEnabled(CoreFeatureFlagType.dynamicPlan),
              let plansDataSource = planService.plansDataSource else {
            // fallback to old, full payment flow
            self.windowService.addToStack(self.allCountriesUpsellViewController(), checkForDuplicates: false)
            return
        }
        let subscriptionViewController = ModalsFactory().subscriptionViewController(plansClient: plansClient(plansDataSource))
        self.windowService.addToStack(subscriptionViewController, checkForDuplicates: false)
    }

    private func plansClient(_ plansDataSource: PlansDataSourceProtocol) -> PlansClient {
        PlansClient(retrievePlans: { [weak self] in
            guard let self else { throw "Onboarding was dismissed" }
            return try await self.planService.planOptions(with: plansDataSource)
        }, validate: { [weak self] in
            await self?.validate(selectedPlan: $0)
        }, notNow: { [weak self] in
            self?.onboardingCoordinatorDidFinish()
        })
    }

    @MainActor
    func validate(selectedPlan: PlanOption) async -> Void {
        let result = await self.planService.buyPlan(planOption: selectedPlan)
        self.buyPlanResultHandler(result)
    }

    private func buyPlanResultHandler(_ result: PurchaseResult) {
        switch result {
        case .purchasedPlan(_):
            // TODO: VPNAPPL-2089 All good?
            self.onboardingCoordinatorDidFinish()
        case .toppedUpCredits:
            break // deprecated
        case .planPurchaseProcessingInProgress(_):
            // TODO: VPNAPPL-2089 should we do anything?
            self.onboardingCoordinatorDidFinish()
        case .purchaseError(_, _):
            // TODO: VPNAPPL-2089 present the error to the user and stay at the screen
            break
        case .apiMightBeBlocked(_, _, _):
            // TODO: VPNAPPL-2089 present the error to the user
            break
        case .purchaseCancelled:
            // TODO: VPNAPPL-2089 do nothing?
            break
        }
    }

    private func allCountriesUpsellViewController() -> UIViewController {
        let serversCount = AccountPlan.plus.serversCount
        let countriesCount = self.planService.countriesCount
        let allCountriesUpsell: ModalType = .allCountries(numberOfServers: serversCount, numberOfCountries: countriesCount)
        return ModalsFactory().modalViewController(modalType: allCountriesUpsell) {
            self.planService.createPlusPlanUI {
                self.onboardingCoordinatorDidFinish()
            }
        } dismissAction: {
            self.onboardingCoordinatorDidFinish()
        }
    }
}

extension OnboardingModuleService {
    private func onboardingCoordinatorDidFinish() {
        log.debug("Onboarding finished", category: .app)
        delegate?.onboardingServiceDidFinish()
    }
}
