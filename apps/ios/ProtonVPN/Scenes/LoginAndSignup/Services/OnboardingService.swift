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
import Modals
import Persistence
import VPNShared

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

    @MainActor
    func showPaywall()
}

final class OnboardingModuleService {
    typealias Factory = CoreAlertServiceFactory & NavigationServiceFactory & PlanServiceFactory & WindowServiceFactory

    private let windowService: WindowService
    private let planService: PlanService
    private let alertService: CoreAlertService
    private let modalsFactory: ModalsFactory
    private let navigationService: NavigationService

    private var oneClickPayment: OneClickPayment?
    private var oneClickIapVC: UIViewController?

    weak var delegate: OnboardingServiceDelegate?

    init(factory: Factory) {
        self.windowService = factory.makeWindowService()
        self.planService = factory.makePlanService()
        self.alertService = factory.makeCoreAlertService()
        self.modalsFactory = ModalsFactory()
        self.navigationService = factory.makeNavigationService()
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

    func showPaywall() {
        log.debug("Starting paywall", category: .app)
        guard let oneClickIapVC = createOneClickIapVC() else {
            // if for any reason we didn't show oneClick, we should present main interface
            return onboardingCoordinatorDidFinish()
        }
        let navigationController = UINavigationController(rootViewController: oneClickIapVC)
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
        guard let oneClickIapVC = createOneClickIapVC() else {
            // if for any reason we didn't show oneClick, we should present main interface
            return onboardingCoordinatorDidFinish()
        }
        windowService.addToStack(oneClickIapVC, checkForDuplicates: false)
    }

    private func createOneClickIapVC() -> UIViewController? {
        let oneClickPayment: OneClickPayment
        do {
            oneClickPayment = try OneClickPayment(
                alertService: alertService,
                windowService: windowService,
                planService: planService,
                payments: planService.payments,
                createAccountFirstClosure: { [weak self] in
                    guard let oneClickIapVC = self?.oneClickIapVC else { return }
                    self?.navigationService.presentSignUp(over: oneClickIapVC, flow: .credentiallessUpsell)
                }
            )
        } catch {
            log.error("Encountered payments error: \(error)")
            windowService.dismissModal {
                self.onboardingCoordinatorDidFinish()
            }
            return nil
        }

        oneClickPayment.completionHandler = { [weak self] in
            self?.onboardingCoordinatorDidFinish()
        }

        let oneClickIapVC = oneClickPayment.oneClickIAPViewController(dismissAction: {
            self.windowService.dismissModal {
                self.onboardingCoordinatorDidFinish()
            }
        })
        self.oneClickPayment = oneClickPayment
        self.oneClickIapVC = oneClickIapVC

        return oneClickIapVC
    }
}

extension OnboardingModuleService {
    private func onboardingCoordinatorDidFinish() {
        log.debug("Onboarding finished", category: .app)
        delegate?.onboardingServiceDidFinish()
    }
}
