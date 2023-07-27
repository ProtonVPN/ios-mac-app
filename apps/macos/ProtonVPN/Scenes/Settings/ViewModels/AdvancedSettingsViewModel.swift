//
//  Created on 24.02.2022.
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

import LegacyCommon
import VPNShared
import LocalFeatureFlags
import Strings

final class AdvancedSettingsViewModel {
    typealias Factory = PropertiesManagerFactory
        & NATTypePropertyProviderFactory
        & SafeModePropertyProviderFactory
        & CoreAlertServiceFactory
        & VpnStateConfigurationFactory
        & VpnGatewayFactory
        & VpnManagerFactory
        & TelemetrySettingsFactory
    private let factory: Factory

    private lazy var vpnGateway: VpnGatewayProtocol = factory.makeVpnGateway()
    private lazy var vpnManager: VpnManagerProtocol = factory.makeVpnManager()
    private lazy var vpnStateConfiguration: VpnStateConfiguration = factory.makeVpnStateConfiguration()
    private lazy var alertService: CoreAlertService = factory.makeCoreAlertService()
    private lazy var propertiesManager: PropertiesManagerProtocol = factory.makePropertiesManager()
    private lazy var natTypePropertyProvider: NATTypePropertyProvider = factory.makeNATTypePropertyProvider()
    private lazy var safeModePropertyProvider: SafeModePropertyProvider = factory.makeSafeModePropertyProvider()
    private lazy var telemetrySettings: TelemetrySettings = factory.makeTelemetrySettings()

    private var featureFlags: FeatureFlags {
        return propertiesManager.featureFlags
    }

    var reloadNeeded: (() -> Void)?

    init(factory: Factory) {
        self.factory = factory
        NotificationCenter.default.addObserver(self, selector: #selector(settingsChanged), name: type(of: natTypePropertyProvider).natTypeNotification, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(settingsChanged), name: type(of: propertiesManager).featureFlagsNotification, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(settingsChanged), name: type(of: safeModePropertyProvider).safeModeNotification, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(settingsChanged), name: type(of: propertiesManager).vpnAcceleratorNotification, object: nil)
    }

    deinit {
        NotificationCenter.default.removeObserver(self)
    }

    var alternativeRouting: Bool {
        return propertiesManager.alternativeRouting
    }

    var isNATTypeFeatureEnabled: Bool {
        return featureFlags.moderateNAT
    }

    var isTelemetryFeatureEnabled: Bool {
        LocalFeatureFlags.isEnabled(TelemetryFeature.telemetryOptIn)
    }

    var usageData: Bool {
        get {
            telemetrySettings.telemetryUsageData
        }
        set {
            telemetrySettings.updateTelemetryUsageData(isOn: newValue)
        }
    }

    var crashReports: Bool {
        get {
            telemetrySettings.telemetryCrashReports
        }
        set {
            telemetrySettings.updateTelemetryCrashReports(isOn: newValue)
        }
    }

    var natType: NATType {
        return natTypePropertyProvider.natType
    }

    var isSafeModeFeatureEnabled: Bool {
        return featureFlags.safeMode
    }

    var safeMode: Bool {
        return safeModePropertyProvider.safeMode ?? true
    }

    // MARK: - Setters

    func setNatType(natType: NATType, completion: @escaping ((Bool) -> Void)) {
        guard natTypePropertyProvider.isUserEligibleForNATTypeChange else {
            alertService.push(alert: ModerateNATUpsellAlert())
            completion(false)
            return
        }

        vpnStateConfiguration.getInfo { [weak self] info in
            switch VpnFeatureChangeState(state: info.state, vpnProtocol: info.connection?.vpnProtocol) {
            case .withConnectionUpdate:
                // in-place change when connected and using local agent
                self?.vpnManager.set(natType: natType)
                self?.natTypePropertyProvider.natType = natType
                completion(true)
            case .withReconnect:
                self?.alertService.push(alert: ReconnectOnActionAlert(actionTitle: Localizable.moderateNatTitle, confirmHandler: { [weak self] in
                    self?.natTypePropertyProvider.natType = natType
                    log.info("Connection will restart after VPN feature change", category: .connectionConnect, event: .trigger, metadata: ["feature": "natType"])
                    self?.vpnGateway.retryConnection()
                    completion(true)
                }, cancelHandler: {
                    completion(false)
                }))
            case .immediately:
                self?.natTypePropertyProvider.natType = natType
                completion(true)
            }
        }
    }

    func setSafeMode(safeMode: Bool, completion: @escaping ((Bool) -> Void)) {
        guard safeModePropertyProvider.isUserEligibleForSafeModeChange else {
            alertService.push(alert: SafeModeUpsellAlert())
            completion(false)
            return
        }

        vpnStateConfiguration.getInfo { [weak self] info in
            switch VpnFeatureChangeState(state: info.state, vpnProtocol: info.connection?.vpnProtocol) {
            case .withConnectionUpdate:
                // in-place change when connected and using local agent
                self?.vpnManager.set(safeMode: safeMode)
                self?.safeModePropertyProvider.safeMode = safeMode
                completion(true)
            case .withReconnect:
                self?.alertService.push(alert: ReconnectOnActionAlert(actionTitle: Localizable.nonStandardPortsTitle, confirmHandler: { [weak self] in
                    self?.safeModePropertyProvider.safeMode = safeMode
                    log.info("Connection will restart after VPN feature change", category: .connectionConnect, event: .trigger, metadata: ["feature": "safeMode"])
                    self?.vpnGateway.retryConnection()
                    completion(true)
                }, cancelHandler: {
                    completion(false)
                }))
            case .immediately:
                self?.safeModePropertyProvider.safeMode = safeMode
                completion(true)
            }
        }
    }

    func setAlternatveRouting(_ enabled: Bool) {
        propertiesManager.alternativeRouting = enabled
    }

    @objc private func settingsChanged() {
        reloadNeeded?()
    } 
}
