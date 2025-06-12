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

import Dependencies

import ProtonCoreFeatureFlags

import LegacyCommon
import Persistence
import VPNShared
import Modals

protocol OnboardingServiceFactory: AnyObject {
    func makeOnboardingService() -> OnboardingService
}

protocol OnboardingServiceDelegate: AnyObject {
    var telemetrySettings: TelemetrySettings { get }
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
        if FeatureFlagsRepository.isRedesigniOSEnabled {
            modalsFactory.modalViewController(modalType: .onboardingWelcome, primaryAction: {
                let getStartedVC = self.onboardingGetStartedViewController()
                self.windowService.addToStack(getStartedVC, checkForDuplicates: false)
            })
        } else {
            modalsFactory.modalViewController(modalType: .welcomeToProton, primaryAction: {
                self.postOnboardingAction()
            })
        }
    }

    private func onboardingGetStartedViewController() -> UIViewController {
        assert(FeatureFlagsRepository.isRedesigniOSEnabled)

        return modalsFactory.modalViewController(modalType: .onboardingGetStarted) {
            self.postOnboardingAction()
        } onFeatureUpdate: { feature in
            switch feature {
            case let .toggle(.statistics, _, _, state):
                self.delegate?.telemetrySettings.updateTelemetryUsageData(isOn: state)
            case let .toggle(.crashes, _, _, state):
                self.delegate?.telemetrySettings.updateTelemetryCrashReports(isOn: state)
            default:
                assertionFailure("Onboarding interactive feature not handled")
            }
        }
    }

    func postOnboardingAction() {
        let oneClickPayment: OneClickPayment
        do {
            oneClickPayment = try OneClickPayment(
                alertService: alertService,
                planService: planService,
                payments: planService.payments
            )
        } catch {
            log.error("Encountered payments error: \(error)")
            self.windowService.dismissModal {
                self.onboardingCoordinatorDidFinish()
            }
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
}

extension OnboardingModuleService {
    private func onboardingCoordinatorDidFinish() {
        log.debug("Onboarding finished", category: .app)
        delegate?.onboardingServiceDidFinish()
    }
}
