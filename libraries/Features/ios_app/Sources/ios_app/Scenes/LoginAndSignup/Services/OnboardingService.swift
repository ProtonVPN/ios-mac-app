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
import Sharing

import ProtonCoreFeatureFlags

import Domain
import LegacyCommon
import Modals
import Persistence
import Telemetry
import VPNShared

protocol OnboardingServiceFactory: AnyObject {
    func makeOnboardingService() -> OnboardingService
}

protocol OnboardingServiceDelegate: AnyObject {
    func onboardingServiceDidFinish()
}

protocol OnboardingService: AnyObject {
    var delegate: OnboardingServiceDelegate? { get set }

    @MainActor
    func showOnboarding(overTabBarController tabBarController: UITabBarController?)

    @MainActor
    func showPaywall()
}

final class OnboardingModuleService {
    typealias Factory = CoreAlertServiceFactory & NavigationServiceFactory & PlanServiceFactory

    @Dependency(\.windowService) private var windowService
    private let planService: PlanService
    private let alertService: CoreAlertService
    private let modalsFactory: ModalsFactory
    private let navigationService: NavigationService

    private var oneClickPayment: OneClickPayment?
    private var oneClickPaymentV2: OneClickPaymentV2?
    private var oneClickIapVC: UIViewController?

    weak var delegate: OnboardingServiceDelegate?

    init(factory: Factory) {
        self.planService = factory.makePlanService()
        self.alertService = factory.makeCoreAlertService()
        self.modalsFactory = ModalsFactory()
        self.navigationService = factory.makeNavigationService()
    }
}

@MainActor
extension OnboardingModuleService: OnboardingService {
    func showOnboarding(overTabBarController tabBarController: UITabBarController? = nil) {
        log.debug("Starting onboarding", category: .app)
        let navigationController = UINavigationController(rootViewController: welcomeToProtonViewController())
        navigationController.setNavigationBarHidden(true, animated: false)
        if tabBarController != nil {
            // we're showing onboarding over tabbar, guest -> create account
            navigationController.modalPresentationStyle = .fullScreen
            windowService.present(modal: navigationController)
        } else {
            windowService.show(viewController: navigationController)
        }
    }

    func showPaywall() {
        log.debug("Starting paywall", category: .app)
        guard let oneClickIapVC = createOneClickIapVC() else {
            // if for any reason we didn't show oneClick, `createOneClickIapVC` will present the main interface instead
            return
        }
        let navigationController = UINavigationController(rootViewController: oneClickIapVC)
        navigationController.setNavigationBarHidden(true, animated: false)
        windowService.show(viewController: navigationController)
    }

    private func welcomeToProtonViewController() -> UIViewController {
        modalsFactory.modalViewController(modalType: .onboardingWelcome, primaryAction: { [weak self] in
            guard let self else { return }
            let getStartedVC = onboardingGetStartedViewController()
            windowService.addToStack(getStartedVC, checkForDuplicates: false)
        })
    }

    private func onboardingGetStartedViewController() -> UIViewController {
        modalsFactory.modalViewController(modalType: .onboardingGetStarted) { [weak self] in
            self?.postOnboardingAction()
        } onFeatureUpdate: { feature in
            @Shared(.telemetryUsageData) var telemetryUsageDataShared
            @Shared(.telemetryCrashReports) var telemetryCrashReportsShared

            switch feature {
            case let .toggle(.statistics, _, _, state):
                $telemetryUsageDataShared.withLock { $0 = String(state) }
            case let .toggle(.crashes, _, _, state):
                $telemetryCrashReportsShared.withLock { $0 = String(state) }
            default:
                log.assertionFailure("Onboarding interactive feature not handled")
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
        let viewController: UIViewController
        if FeatureFlagsRepository.shared.isEnabled(CoreFeatureFlagType.paymentsV2) {
            let oneClickPaymentV2: OneClickPaymentV2
            do {
                oneClickPaymentV2 = try OneClickPaymentV2(
                    alertService: alertService,
                    windowService: windowService,
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

            oneClickPaymentV2.completionHandler = { [weak self] completion in
                self?.onboardingCoordinatorDidFinish()
                completion?()
            }

            viewController = oneClickPaymentV2.oneClickIAPViewController(dismissAction: { [weak self] in
                self?.windowService.dismissModal {
                    self?.onboardingCoordinatorDidFinish()
                }
            })
            self.oneClickPaymentV2 = oneClickPaymentV2
        } else {
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

            viewController = oneClickPayment.oneClickIAPViewController(dismissAction: { [weak self] in
                self?.windowService.dismissModal {
                    self?.onboardingCoordinatorDidFinish()
                }
            })
            self.oneClickPayment = oneClickPayment
        }
        oneClickIapVC = viewController
        return oneClickIapVC
    }
}

extension OnboardingModuleService {
    private func onboardingCoordinatorDidFinish() {
        log.debug("Onboarding finished", category: .app)
        delegate?.onboardingServiceDidFinish()
    }
}
