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
import Modals_iOS
import Modals
import UIKit

public typealias OnboardingConnectionRequestCompletion = (Country?) -> Void
public typealias OnboardingPlanPurchaseCompletion = (PlanPurchaseAction) -> Void

public protocol OnboardingCoordinatorDelegate: AnyObject {
    func onboardingCoordinatorDidFinish(requiresConnection: Bool)
    func userDidRequestConnection(completion: @escaping OnboardingConnectionRequestCompletion)
    func userDidRequestPlanPurchase(completion: @escaping OnboardingPlanPurchaseCompletion)
    func preferenceChangeUsageData(telemetryUsageData: Bool)
    func preferenceChangeCrashReports(telemetryCrashReports: Bool)
}

public final class OnboardingCoordinator {

    // MARK: Properties

    private let storyboard: UIStoryboard
    private let navigationController: UINavigationController
    private let configuration: Configuration
    private var popOverNavigationController: UINavigationController?
    private var onboardingFinished = false
    private let modals: ModalsFactory

    public weak var delegate: OnboardingCoordinatorDelegate?

    // MARK: Setup

    public init(configuration: Configuration) {
        self.configuration = configuration
        self.modals = ModalsFactory()

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

    private func showTelemetry(preferenceChangeUsageData: @escaping (Bool) -> Void,
                               preferenceCrashReports: @escaping (Bool) -> Void,
                               completion: @escaping () -> Void) {
        let telemetryViewController = TelemetryViewController()
        telemetryViewController.completion = completion
        telemetryViewController.preferenceChangeUsageData = preferenceChangeUsageData
        telemetryViewController.preferenceChangeCrashReports = preferenceCrashReports
        navigationController.pushViewController(telemetryViewController, animated: true)
    }

    private func showNoLogs() {
        let noLogsViewController = modals.upsellViewController(upsellType: .noLogs)
        noLogsViewController.delegate = self
        navigationController.pushViewController(noLogsViewController, animated: true)
    }

    private func showConnectionSetup(animated: Bool = true) {
        guard !(navigationController.topViewController is ConnectionViewController) else {
            return
        }

        let connectionViewController = storyboard.instantiate(controllerType: ConnectionViewController.self)
        connectionViewController.constants = configuration.constants
        connectionViewController.delegate = self
        navigationController.pushViewController(connectionViewController, animated: animated)
    }

    private func showConnected(state: ConnectedState) {
        let connectedViewController = storyboard.instantiate(controllerType: ConnectedViewController.self)
        connectedViewController.delegate = self
        connectedViewController.state = state
        navigationController.pushViewController(connectedViewController, animated: true)
    }

    private func showUpsell() {
        let const = configuration.constants
        let upsell = UpsellType.allCountries(numberOfServers: const.numberOfServers, numberOfCountries: const.numberOfCountries)
        let upsellViewController = modals.upsellViewController(upsellType: upsell)
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
        connectToPlusServerViewController.constants = configuration.constants
        connectToPlusServerViewController.delegate = self
        navigationController.pushViewController(connectToPlusServerViewController, animated: false)
        popOverNavigationController?.dismiss(animated: true)
    }
}

// MARK: Modals Colors

extension Colors: ModalsColors { }

// MARK: Welcome screen delegate

extension OnboardingCoordinator: WelcomeViewControllerDelegate {
    func userDidRequestTakeTour() {
        showTour()
    }
}

// MARK: Tour screen delegate

extension OnboardingCoordinator: TourViewControllerDelegate {
    func userDidRequestSkipTour() {
        guard configuration.telemetryEnabled else {
            showNoLogs()
            return
        }
        showTelemetry(preferenceChangeUsageData: { usageData in
            self.delegate?.preferenceChangeUsageData(telemetryUsageData: usageData)
        },
                      preferenceCrashReports: { crashReports in
            self.delegate?.preferenceChangeCrashReports(telemetryCrashReports: crashReports)
        },
                      completion: { [weak self] in
            self?.showNoLogs()
        })
    }
}

// MARK: Connected screen delegate

extension OnboardingCoordinator: ConnectedViewControllerDelegate {
    func userDidFinish() {
        onboardingFinished = true
        showUpsell()
    }
}

// MARK: Connection screen delegate

extension OnboardingCoordinator: ConnectionViewControllerDelegate {
    func userDidRequestPurchaseFromConnection() {
        showUpsell()
    }

    func userDidRequestSkipConnection() {
        showConnected(state: .notConnected)
    }

    func userDidRequestConnection() {
        delegate?.userDidRequestConnection { [weak self] country in
            guard let country = country else {
                self?.showConnected(state: .error)
                return
            }

            self?.showConnected(state: .connected(country))
        }
    }
}

// MARK: Upsell screen delegate

extension OnboardingCoordinator: UpsellViewControllerDelegate {
    public func shouldDismissUpsell(upsell: UpsellViewController?) -> Bool {
        if onboardingFinished {
            delegate?.onboardingCoordinatorDidFinish(requiresConnection: false)
            return false
        }

        popOverNavigationController?.dismiss(animated: true, completion: nil)
        return false
    }

    public func userDidDismissUpsell(upsell: UpsellViewController?) {

    }

    public func userDidRequestPlus(upsell: UpsellViewController?) {
        showGetPlus()
    }

    public func userDidTapNext(upsell: UpsellViewController) {
        showConnectionSetup()
    }

    public func upsellDidDisappear(upsell: UpsellViewController?) {
    }
}

// MARK: Connect to Plus screen delegate

extension OnboardingCoordinator: ConnectToPlusServerViewControllerDelegate {
    func userDidRequestSkipConnectToPlus() {
        delegate?.onboardingCoordinatorDidFinish(requiresConnection: false)
    }

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
