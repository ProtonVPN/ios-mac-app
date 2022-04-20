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

    func showOnboarding(showFirstConnection: Bool)
}

final class OnboardingModuleService {
    typealias Factory = WindowServiceFactory
        & VpnGatewayFactory
        & AppStateManagerFactory
        & PlanServiceFactory

    private let windowService: WindowService
    private let vpnGateway: VpnGatewayProtocol
    private let appStateManager: AppStateManager
    private let planService: PlanService

    private var onboardingCoordinator: OnboardingCoordinator?
    private var completion: OnboardingConnectionRequestCompletion?

    weak var delegate: OnboardingServiceDelegate?

    init(factory: Factory) {
        windowService = factory.makeWindowService()
        vpnGateway = factory.makeVpnGateway()
        appStateManager = factory.makeAppStateManager()
        planService = factory.makePlanService()

        NotificationCenter.default.addObserver(self, selector: #selector(connectionChanged), name: AppStateManagerNotification.displayStateChange, object: nil)
    }

    @objc private func connectionChanged(_ notification: NSNotification) {
        switch appStateManager.displayState {
        case .connected:
            guard let connection = appStateManager.activeConnection() else {
                return
            }

            log.debug("Onboarding VPN connection successful", category: .app)
            completion?(Country(name: connection.server.country, flag: UIImage.flag(countryCode: connection.server.countryCode)))
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
    func showOnboarding(showFirstConnection: Bool) {
        log.debug("Starting onboarding \(showFirstConnection ? "A" : "B")", category: .app)

        onboardingCoordinator = OnboardingCoordinator(configuration: Configuration(showFirstConnection: showFirstConnection))
        onboardingCoordinator?.delegate = self
        let viewController = onboardingCoordinator!.start()
        windowService.show(viewController: viewController)
    }
}

extension OnboardingModuleService: OnboardingCoordinatorDelegate {
    func userDidRequestPlanPurchase(completion: @escaping OnboardingPlanPurchaseCompletion) {
        planService.createPlusPlanUI { result in
            switch result {
            case let .planPurchaseViewControllerCreated(viewController):
                completion(.planPurchaseViewControllerReady(viewController))
            case .planPurchased:
                completion(.planPurchased)
            }
        }
    }

    func onboardingCoordinatorDidFinish(requiresConnection: Bool) {
        log.debug("Onboarding finished", category: .app)

        delegate?.onboardingServiceDidFinish()

        if requiresConnection {
            log.debug("Doing quick connect required by finished onboarding", category: .app)
            vpnGateway.quickConnect()
        }
    }

    func userDidRequestConnection(completion: @escaping OnboardingConnectionRequestCompletion) {
        log.debug("Onboarding requested VPN connection", category: .app)
        self.completion = completion

        vpnGateway.quickConnect()
    }
}
