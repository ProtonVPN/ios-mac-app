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

public protocol OnboardingCoordinatorDelegate: AnyObject {
    func onboardingCoordinatorDidFinish()
    func userDidRequestConnection(completion: @escaping (Result<Country, Error>) -> Void)
}

public final class OnboardingCoordinator {

    // MARK: Properties

    private let storyboard: UIStoryboard
    private let navigationController: UINavigationController

    public weak var delegate: OnboardingCoordinatorDelegate?

    // MARK: Setup

    public init(configuration: Configuration) {
        colors = configuration.colors
        storyboard = UIStoryboard(name: "Storyboard", bundle: Bundle.module)
        navigationController = UINavigationController()
        navigationController.setNavigationBarHidden(true, animated: false)
    }

    // MARK: Actions

    public func start() -> UIViewController {
        let welcomeViewController = storyboard.instantiateViewController(withIdentifier: "Welcome") as! WelcomeViewController
        welcomeViewController.delegate = self
        navigationController.pushViewController(welcomeViewController, animated: false)
        return navigationController
    }

    // MARK: Internal

    private func showTour() {
        let tourViewController = storyboard.instantiateViewController(withIdentifier: "Tour") as! TourViewController
        tourViewController.delegate = self
        navigationController.pushViewController(tourViewController, animated: true)
    }

    private func showConnectionSetup() {
        let connectionViewController = storyboard.instantiateViewController(withIdentifier: "Connection") as! ConnectionViewController
        connectionViewController.delegate = self
        navigationController.pushViewController(connectionViewController, animated: true)
    }

    private func showConnected(country: Country) {
        let connectedViewController = storyboard.instantiateViewController(withIdentifier: "Connected") as! ConnectedViewController
        connectedViewController.delegate = self
        connectedViewController.country = country
        navigationController.pushViewController(connectedViewController, animated: true)
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
        showConnectionSetup()
    }
}

// MARK: Connected screen delegate

extension OnboardingCoordinator: ConnectedViewControllerDelegate {
    func userDidFinish() {
        delegate?.onboardingCoordinatorDidFinish()
    }
}

// MARK: Connection screen delegate

extension OnboardingCoordinator: ConnectionViewControllerDelegate {
    func userDidRequestConnection(completion: @escaping (Result<Country, Error>) -> Void) {
        delegate?.userDidRequestConnection { result in
            switch result {
            case let .failure(error):
                executeOnUIThread {
                    completion(.failure(error))
                }
            case let .success(county: country):
                executeOnUIThread {
                    self.showConnected(country: country)
                }
            }
        }
    }
}
