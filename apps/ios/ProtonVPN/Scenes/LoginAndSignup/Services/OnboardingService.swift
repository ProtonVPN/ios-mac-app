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
import LegacyCommon
import LocalFeatureFlags
import VPNShared
import Modals
import Modals_iOS

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
        ModalsFactory().modalViewController(upsellType: .welcomeToProton, primaryAction:  {
            self.windowService.addToStack(self.allCountriesUpsellViewController(), 
                                          checkForDuplicates: false)
        })
    }

    private func allCountriesUpsellViewController() -> UIViewController {
        let serversCount = AccountPlan.plus.serversCount
        let countriesCount = self.planService.countriesCount
        let allCountriesUpsell: UpsellType = .allCountries(numberOfServers: serversCount, numberOfCountries: countriesCount)
        return ModalsFactory().modalViewController(upsellType: allCountriesUpsell) {
            self.userDidRequestPlanPurchase { action in
                switch action {
                case .planPurchased:
                    self.onboardingCoordinatorDidFinish()
                case .planPurchaseViewControllerReady(let viewController):
                    self.windowService.present(modal: viewController)
                }
            }
        } dismissAction: {
            self.onboardingCoordinatorDidFinish()
        }
    }
}

extension OnboardingModuleService {
    func userDidRequestPlanPurchase(completion: @escaping (PlanPurchaseAction) -> Void) {
        planService.createPlusPlanUI { result in
            switch result {
            case let .planPurchaseViewControllerCreated(viewController):
                completion(.planPurchaseViewControllerReady(viewController))
            case .planPurchased:
                completion(.planPurchased)
            }
        }
    }

    func onboardingCoordinatorDidFinish() {
        log.debug("Onboarding finished", category: .app)
        delegate?.onboardingServiceDidFinish()
    }
}

enum PlanPurchaseAction {
    case planPurchaseViewControllerReady(UIViewController)
    case planPurchased
}
