//
//  Created on 03.01.2022.
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

public typealias OnboardingConnectionRequestCompletion = (Country?) -> Void
public typealias OnboardingPlanPurchaseCompletion = (PlanPurchaseAction) -> Void

public protocol OnboardingCoordinatorDelegate: AnyObject {
    func onboardingCoordinatorDidFinish(requiresConnection: Bool)
    func userDidRequestConnection(completion: @escaping OnboardingConnectionRequestCompletion)
    func userDidRequestPlanPurchase(completion: @escaping OnboardingPlanPurchaseCompletion)
}

public final class OnboardingCoordinator {

    // MARK: Properties

    private let storyboard: UIStoryboard
    private let navigationController: UINavigationController
    private let configuration: Configuration
    private var popOverNavigationController: UINavigationController?
    private var onboardingFinished = false

    public weak var delegate: OnboardingCoordinatorDelegate?

    // MARK: Setup

    public init(configuration: Configuration) {
        self.configuration = configuration

        colors = configuration.colors
        storyboard = UIStoryboard(name: "Storyboard", bundle: Bundle.module)
        navigationController = UINavigationController()
        navigationController.setNavigationBarHidden(true, animated: false)
    }

    // MARK: Actions

    public func start() -> UIViewController {
        let welcomeViewController = storyboard.instantiate(controllerType: WelcomeViewController.self)
        welcomeViewController.delegate = self
        navigationController.pushViewController(welcomeViewController, animated: false)
        return navigationController
    }

    // MARK: Internal

    private func showTour() {
        let tourViewController = storyboard.instantiate(controllerType: TourViewController.self)
        tourViewController.delegate = self
        navigationController.pushViewController(tourViewController, animated: true)
    }

    private func showConnectionSetup(animated: Bool = true) {
        guard !(navigationController.topViewController is ConnectionViewController) else {
            return
        }

        let connectionViewController = storyboard.instantiate(controllerType: ConnectionViewController.self)
        connectionViewController.delegate = self
        navigationController.pushViewController(connectionViewController, animated: animated)
    }

    private func showConnected(country: Country?) {
        let connectedViewController = storyboard.instantiate(controllerType: ConnectedViewController.self)
        connectedViewController.delegate = self
        connectedViewController.country = country
        navigationController.pushViewController(connectedViewController, animated: true)
    }

    private func showUpsell() {
        let upsellViewController = storyboard.instantiate(controllerType: UpsellViewController.self)
        upsellViewController.delegate = self
        let popOverNavigationController = UINavigationController(rootViewController: upsellViewController)
        navigationStyle(popOverNavigationController)
        self.popOverNavigationController = popOverNavigationController
        navigationController.present(popOverNavigationController, animated: true, completion: nil)
    }

    private func showGetPlus() {
        delegate?.userDidRequestPlanPurchase { [weak self] action in
            guard let self = self else {
                return
            }

            switch action {
            case let .planPurchaseViewControllerReady(planPurchaseViewController):
                let getPlusViewController = self.storyboard.instantiate(controllerType: GetPlusViewController.self)
                getPlusViewController.delegate = self
                getPlusViewController.planPurchaseViewController = planPurchaseViewController
                executeOnUIThread { [weak self] in
                    self?.popOverNavigationController?.pushViewController(getPlusViewController, animated: true)
                }
            case .planPurchased:
                executeOnUIThread { [weak self] in
                    self?.showConnectToPlusServer()
                }
            }
        }
    }

    private func showConnectToPlusServer() {
        let connectToPlusServerViewController = storyboard.instantiate(controllerType: ConnectToPlusServerViewController.self)
        connectToPlusServerViewController.delegate = self
        navigationController.pushViewController(connectToPlusServerViewController, animated: false)
        popOverNavigationController?.dismiss(animated: true)
    }
}

// MARK: Welcome screen delegate

extension OnboardingCoordinator: WelcomeViewControllerDelegate {
    func userDidRequestTakeTour() {
        showTour()
    }
}

// MARK: Tour screen delegate

extension OnboardingCoordinator: TourViewControllerDelegate {
    func userDidRequestSkipTour() {
        switch configuration.variant {
        case .A:
            showConnectionSetup()
        case .B:
            showUpsell()
        }
    }
}

// MARK: Connected screen delegate

extension OnboardingCoordinator: ConnectedViewControllerDelegate {
    func userDidFinish() {
        switch configuration.variant {
        case .A:
            onboardingFinished = true
            showUpsell()
        case .B:
            delegate?.onboardingCoordinatorDidFinish(requiresConnection: false)
        }
    }
}

// MARK: Connection screen delegate

extension OnboardingCoordinator: ConnectionViewControllerDelegate {
    func userDidRequestPurchaseFromConnection() {
        showUpsell()
    }

    func userDidRequestSkipConnection() {
        showConnected(country: nil)
    }

    func userDidRequestConnection() {
        delegate?.userDidRequestConnection { [weak self] country in
            self?.showConnected(country: country)
        }
    }
}

// MARK: Upsell screen delegate

extension OnboardingCoordinator: UpsellViewControllerDelegate {
    func userDidDismissUpsell() {
        switch configuration.variant {
        case .A:
            if onboardingFinished {
                delegate?.onboardingCoordinatorDidFinish(requiresConnection: false)
                return
            }

            popOverNavigationController?.dismiss(animated: true, completion: nil)
        case .B:
            showConnectionSetup(animated: false)
            popOverNavigationController?.dismiss(animated: true, completion: nil)
        }
    }

    func userDidRequestPlus() {
        showGetPlus()
    }
}

// MARK: Connect to Plus screen delegate

extension OnboardingCoordinator: ConnectToPlusServerViewControllerDelegate {
    func userDidRequestConnectToPlus() {
        delegate?.onboardingCoordinatorDidFinish(requiresConnection: true)
    }
}

// MARK: Get Plus screen delegate

extension OnboardingCoordinator: GetPlusViewControllerDelegate {
    func userDidRequestBackFromGetPlus() {
        popOverNavigationController?.popViewController(animated: true)
    }
}
