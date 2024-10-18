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
import Dependencies
import Persistence

import ProtonCoreFeatureFlags

protocol OnboardingServiceFactory: AnyObject {
    func makeOnboardingService() -> OnboardingService
}

protocol OnboardingServiceDelegate: AnyObject {
    func onboardingServiceDidFinish()
}

protocol OnboardingService: AnyObject {
    var delegate: OnboardingServiceDelegate? { get set }

    @MainActor
    func showOnboarding()
}

final class OnboardingModuleService {
    typealias Factory = WindowServiceFactory & PlanServiceFactory & CoreAlertServiceFactory

    private let windowService: WindowService
    private let planService: PlanService
    private let alertService: CoreAlertService
    private let modalsFactory: ModalsFactory

    private var oneClickPayment: OneClickPayment?

    weak var delegate: OnboardingServiceDelegate?

    init(factory: Factory) {
        self.windowService = factory.makeWindowService()
        self.planService = factory.makePlanService()
        self.alertService = factory.makeCoreAlertService()
        self.modalsFactory = ModalsFactory()
    }
}

@MainActor
extension OnboardingModuleService: OnboardingService {
    func showOnboarding() {
        log.debug("Starting onboarding", category: .app)
        let navigationController = UINavigationController(rootViewController: welcomeToProtonViewController())
        navigationController.setNavigationBarHidden(true, animated: false)
        windowService.show(viewController: navigationController)
    }

    private func welcomeToProtonViewController() -> UIViewController {
        modalsFactory.modalViewController(modalType: .onboardingWelcome, primaryAction: {
            if FeatureFlagsRepository.shared.isRedesigniOSEnabled {
                let getStartedVC = self.welcomeGetStartedViewController()
                self.windowService.addToStack(getStartedVC, checkForDuplicates: false)
            } else {
                self.postOnboardingAction()
            }
        })
    }

    private func welcomeGetStartedViewController() -> UIViewController {
        assert(FeatureFlagsRepository.shared.isRedesigniOSEnabled)

        return modalsFactory.modalViewController(modalType: .onboardingGetStarted) {
            self.postOnboardingAction()
        } onFeatureUpdate: { feature in
            switch feature {
            case .toggle(.statistics, _, _, let state):
                break // TODO: VPNAPPL-2407
            case .toggle(.crashes, _, _, let state):
                break // TODO: VPNAPPL-2407
            default:
                assertionFailure("Onboarding interactive feature not handled")
            }
        }
    }

    func postOnboardingAction() {
        guard let oneClickPayment = OneClickPayment(
            alertService: alertService,
            planService: planService,
            payments: planService.payments
        ) else {
            // Can be disabled if `DynamicPlan` FF set to false, but this doesn't happen in practice (default is true).
            return
        }

        oneClickPayment.completionHandler = { [weak self] in
            self?.onboardingCoordinatorDidFinish()
        }

        let viewController = oneClickPayment.oneClickIAPViewController(dismissAction: {
            self.windowService.dismissModal {
                self.onboardingCoordinatorDidFinish()
            }
        })
        self.oneClickPayment = oneClickPayment
        windowService.addToStack(viewController, checkForDuplicates: false)
    }

    private func allCountriesUpsellViewController() -> UIViewController {
        @Dependency(\.serverRepository) var repository
        let allCountriesUpsell: ModalType = .allCountries(
            numberOfServers: repository.roundedServerCount,
            numberOfCountries: repository.countryCount()
        )
        return modalsFactory.modalViewController(modalType: allCountriesUpsell) {
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
