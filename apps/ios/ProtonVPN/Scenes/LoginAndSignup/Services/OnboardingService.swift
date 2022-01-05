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
import Onboarding
import UIKit
import vpncore

protocol OnboardingServiceFactory: AnyObject {
    func makeOnboardingService() -> OnboardingService
}

protocol OnboardingServiceDelegate: AnyObject {
    func onboardingServiceDidFinish()
}

protocol OnboardingService: AnyObject {
    var delegate: OnboardingServiceDelegate? { get set }

    func showOnboarding()
}

final class OnboardingModuleService {
    typealias Factory = WindowServiceFactory
        & VpnGatewayFactory
        & AppStateManagerFactory

    private let windowService: WindowService
    private let vpnGateway: VpnGatewayProtocol
    private let appStateManager: AppStateManager

    private var onboardingCoordinator: OnboardingCoordinator?
    private var completion: OnboardingConnectionRequestCompletion?

    weak var delegate: OnboardingServiceDelegate?

    init(factory: Factory) {
        windowService = factory.makeWindowService()
        vpnGateway = factory.makeVpnGateway()
        appStateManager = factory.makeAppStateManager()

        NotificationCenter.default.addObserver(self, selector: #selector(connectionChanged), name: appStateManager.displayStateChange, object: nil)
    }

    @objc private func connectionChanged(_ notification: NSNotification) {
        switch appStateManager.displayState {
        case .connected:
            guard let connection = appStateManager.activeConnection() else {
                return
            }

            let flag = UIImage(named: connection.server.countryCode.lowercased() + "-round") ?? UIImage(named: connection.server.countryCode.lowercased() + "-plain")

            log.debug("Onboarding VPN connection successful", category: .app)
            completion?(Country(name: connection.server.country, flag: flag ?? UIImage()))
            completion = nil
        case .disconnected:
            log.error("Onboarding VPN connection failed", category: .app)
            completion?(nil)
            completion = nil
        default:
            break
        }
    }
}

extension OnboardingModuleService: OnboardingService {
    func showOnboarding() {
        log.debug("Starting onboarding", category: .app)

        onboardingCoordinator = OnboardingCoordinator(configuration: Configuration())
        onboardingCoordinator?.delegate = self
        let viewController = onboardingCoordinator!.start()
        windowService.show(viewController: viewController)
    }
}

extension OnboardingModuleService: OnboardingCoordinatorDelegate {
    func onboardingCoordinatorDidFinish() {
        log.debug("Onboarding finished", category: .app)

        delegate?.onboardingServiceDidFinish()
    }

    func userDidRequestConnection(completion: @escaping OnboardingConnectionRequestCompletion) {
        log.debug("Onboarding requested VPN connection", category: .app)
        self.completion = completion

        vpnGateway.quickConnect()
    }
}
