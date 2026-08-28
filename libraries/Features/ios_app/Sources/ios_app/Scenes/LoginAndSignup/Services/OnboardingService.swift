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

import Dependencies
import Domain
import Foundation
import Modals
import Payments
import Sharing
import UIKit
import VPNShared

protocol OnboardingServiceDelegate: AnyObject {
    func onboardingServiceDidFinish()
}

protocol OnboardingService: AnyObject {
    var delegate: OnboardingServiceDelegate? { get set }

    /// - Parameter overMainInterface: whether the app's shell is already up, which is the guest to registered path.
    ///
    /// Onboarding is presented over it rather than becoming the root.
    @MainActor
    func showOnboarding(overMainInterface: Bool)

    @MainActor
    func showPaywall()
}

final class OnboardingModuleService {
    typealias Factory = NavigationServiceFactory

    @Dependency(\.windowService) private var windowService
    private let modalsFactory: ModalsFactory
    private let navigationService: NavigationService
    private let paymentsFlowCoordinator = PaymentsFlowCoordinator()

    /// The stack onboarding runs in, either the window's root or a modal covering the main interface
    private weak var onboardingNavigation: UIViewController?
    private var oneClickIapVC: UIViewController?

    weak var delegate: OnboardingServiceDelegate?

    init(factory: Factory) {
        self.modalsFactory = ModalsFactory()
        self.navigationService = factory.makeNavigationService()
    }
}

@MainActor
extension OnboardingModuleService: OnboardingService {
    func showOnboarding(overMainInterface: Bool = false) {
        log.debug("Starting onboarding", category: .app)
        let navigationController = UINavigationController(rootViewController: welcomeToProtonViewController())
        navigationController.setNavigationBarHidden(true, animated: false)
        onboardingNavigation = navigationController
        if overMainInterface {
            // guest -> create account: the shell is already showing, so onboarding covers it
            navigationController.modalPresentationStyle = .fullScreen
            windowService.present(modal: navigationController)
        } else {
            windowService.show(viewController: navigationController)
        }
    }

    func showPaywall() {
        log.debug("Starting paywall", category: .app)
        let navigationController = UINavigationController(rootViewController: createOneClickIapVC())
        navigationController.setNavigationBarHidden(true, animated: false)
        onboardingNavigation = navigationController
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
                $telemetryUsageDataShared.withLock { $0 = state }
            case let .toggle(.crashes, _, _, state):
                $telemetryCrashReportsShared.withLock { $0 = state }
            default:
                log.assertionFailure("Onboarding interactive feature not handled")
            }
        }
    }

    func postOnboardingAction() {
        windowService.addToStack(createOneClickIapVC(), checkForDuplicates: false)
    }

    private func createOneClickIapVC() -> UIViewController {
        let viewController = paymentsFlowCoordinator.makeViewController(
            request: .upsell(.subscription),
            onEvent: { [weak self] event in
                guard let self else { return }
                switch event {
                case .completed, .dismissed:
                    onboardingCoordinatorDidFinish()
                case .createAccountFirstRequested:
                    guard let oneClickIapVC else { return }
                    navigationService.presentSignUp(over: oneClickIapVC, flow: .credentiallessUpsell)
                case .engaged:
                    break
                }
            }
        )

        oneClickIapVC = viewController
        return viewController
    }
}

extension OnboardingModuleService {
    @MainActor
    private func onboardingCoordinatorDidFinish() {
        log.debug("Onboarding finished", category: .app)
        guard let onboardingNavigation, onboardingNavigation.presentingViewController != nil else {
            // window's root (delegate will replace)
            delegate?.onboardingServiceDidFinish()
            return
        }
        // modal (to dismiss)
        onboardingNavigation.dismiss(animated: true) { [weak self] in
            self?.delegate?.onboardingServiceDidFinish()
        }
    }
}
