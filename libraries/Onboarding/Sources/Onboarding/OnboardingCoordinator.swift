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
    func userDidRequestConnection(completion: @escaping (Result<(), Error>) -> Void)
}

public final class OnboardingCoordinator {
    private let storyboard: UIStoryboard
    private let navigationController: UINavigationController

    public weak var delegate: OnboardingCoordinatorDelegate?

    public init(configuration: Configuration) {
        colors = configuration.colors
        storyboard = UIStoryboard(name: "Storyboard", bundle: Bundle.module)
        navigationController = UINavigationController()
        navigationController.setNavigationBarHidden(true, animated: false)
    }

    public func start() -> UIViewController {
        let welcomeViewController = storyboard.instantiateViewController(withIdentifier: "Welcome") as! WelcomeViewController
        welcomeViewController.delegate = self
        navigationController.pushViewController(welcomeViewController, animated: false)
        return navigationController
    }

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

    private func showConnected() {
        let connectedViewController = storyboard.instantiateViewController(withIdentifier: "Connected") as! ConnectedViewController
        navigationController.pushViewController(connectedViewController, animated: true)
    }
}

extension OnboardingCoordinator: WelcomeViewControllerDelegate {
    func userDidRequestTakeTour() {
        showTour()
    }
}

extension OnboardingCoordinator: TourViewControllerDelegate {
    func userDidRequestSkipTour() {
        showConnectionSetup()
    }
}

extension OnboardingCoordinator: ConnectionViewControllerDelegate {
    func userDidRequestConnection(completion: @escaping (Result<(), Error>) -> Void) {
        delegate?.userDidRequestConnection { result in
            switch result {
            case let .failure(error):
                DispatchQueue.main.async {
                    completion(.failure(error))
                }
            case .success:
                DispatchQueue.main.async {
                    self.showConnected()
                }
            }
        }
    }
}
