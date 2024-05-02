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
        modalsFactory.modalViewController(modalType: .welcomeToProton, primaryAction: {
            self.welcomeToProtonPrimaryAction()
        })
    }

    func welcomeToProtonPrimaryAction() {
        let viewController: UIViewController
        do {
            let oneClickPayment = try OneClickPayment(alertService: alertService, planService: planService, payments: planService.payments)
            oneClickPayment.completionHandler = { [weak self] in
                self?.onboardingCoordinatorDidFinish()
            }
            viewController = oneClickPayment.oneClickIAPViewController(dismissAction: {
                self.windowService.dismissModal {
                    self.onboardingCoordinatorDidFinish()
                }
            })
            self.oneClickPayment = oneClickPayment
        } catch {
            log.debug("One click payment disabled: \(error)")
            viewController = allCountriesUpsellViewController()
        }
        windowService.addToStack(viewController, checkForDuplicates: false)
    }

    private func allCountriesUpsellViewController() -> UIViewController {
        let serversCount = AccountPlan.plus.serversCount
        let countriesCount = self.planService.countriesCount
        let allCountriesUpsell: ModalType = .allCountries(numberOfServers: serversCount, numberOfCountries: countriesCount)
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
