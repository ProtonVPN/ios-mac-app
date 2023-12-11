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
import LegacyCommon
import LocalFeatureFlags
import VPNShared

protocol OnboardingServiceFactory: AnyObject {
    func makeOnboardingService(vpnGateway: VpnGatewayProtocol) -> OnboardingService
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
        & PlanServiceFactory
        & TelemetrySettingsFactory

    private let windowService: WindowService
    private let vpnGateway: VpnGatewayProtocol
    private let appStateManager: AppStateManager
    private let planService: PlanService
    private let telemetrySettings: TelemetrySettings

    private var onboardingCoordinator: OnboardingCoordinator
    private var completion: OnboardingConnectionRequestCompletion?

    weak var delegate: OnboardingServiceDelegate?

    init(factory: Factory, vpnGateway: VpnGatewayProtocol) {
        windowService = factory.makeWindowService()
        appStateManager = factory.makeAppStateManager()
        planService = factory.makePlanService()
        telemetrySettings = factory.makeTelemetrySettings()
        self.vpnGateway = vpnGateway

        let telemetry = LocalFeatureFlags.isEnabled(TelemetryFeature.telemetryOptIn)
        let onboardingConfiguration = Configuration(telemetryEnabled: telemetry)
        onboardingCoordinator = OnboardingCoordinator(configuration: onboardingConfiguration)
        onboardingCoordinator.delegate = self

        NotificationCenter.default.addObserver(self, selector: #selector(connectionChanged), name: .AppStateManager.displayStateChange, object: nil)
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
    func showOnboarding() {
        log.debug("Starting onboarding", category: .app)
        let viewController = onboardingCoordinator.start()
        windowService.show(viewController: viewController)
    }
}

extension OnboardingModuleService: OnboardingCoordinatorDelegate {
    func preferenceChangeUsageData(telemetryUsageData: Bool) {
        telemetrySettings.updateTelemetryUsageData(isOn: telemetryUsageData)
    }

    func preferenceChangeCrashReports(telemetryCrashReports: Bool) {
        telemetrySettings.updateTelemetryCrashReports(isOn: telemetryCrashReports)
    }

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

    func onboardingCoordinatorDidFinish() {
        log.debug("Onboarding finished", category: .app)

        delegate?.onboardingServiceDidFinish()
    }

    func userDidRequestConnection(completion: @escaping OnboardingConnectionRequestCompletion) {
        log.debug("Onboarding requested VPN connection", category: .app)
        self.completion = completion

        vpnGateway.quickConnect(trigger: .auto)
    }
}
