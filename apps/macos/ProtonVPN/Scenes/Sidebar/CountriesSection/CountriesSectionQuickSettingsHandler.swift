//
//  Created on 17/04/2026 by Max Kupetskyi.
//
//  Copyright (c) 2026 Proton AG
//
//  Proton VPN is free software: you can redistribute it and/or modify
//  it under the terms of the GNU General Public License as published by
//  the Free Software Foundation, either version 3 of the License, or
//  (at your option) any later version.
//
//  Proton VPN is distributed in the hope that it will be useful,
//  but WITHOUT ANY WARRANTY; without even the implied warranty of
//  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
//  GNU General Public License for more details.
//
//  You should have received a copy of the GNU General Public License
//  along with Proton VPN.  If not, see <https://www.gnu.org/licenses/>.

import Dependencies
import Domain
import Foundation
import LegacyCommon
import NetShield
import Sharing
import VPNAppCore
import VPNShared

final class CountriesSectionQuickSettingsHandler {
    private let vpnGateway: VpnGatewayProtocol
    private let appStateManager: AppStateManager

    @Dependency(\.propertiesManager) private var propertiesManager
    @Dependency(\.portForwardingPropertyProvider) private var portForwardingPropertyProvider
    @Dependency(\.netShieldPropertyProvider) private var netShieldPropertyProvider
    @Dependency(\.appFeaturePropertyProvider) private var appFeaturePropertyProvider
    @Dependency(\.vpnStateConfiguration) private var vpnStateConfiguration

    private let quickSettingsVpnManager: VpnManagerProtocol

    init(
        appStateManager: AppStateManager,
        vpnGateway: VpnGatewayProtocol,
        vpnManager: VpnManagerProtocol
    ) {
        self.vpnGateway = vpnGateway
        self.appStateManager = appStateManager
        self.quickSettingsVpnManager = vpnManager
    }

    var quickSettingsInitialNetShieldStats: NetShieldModel {
        quickSettingsVpnManager.netShieldStats
    }

    func quickSettingsSelectOption(
        type: QuickSettingType,
        option: QuickSettingOptionID,
        dismiss: @escaping () -> Void
    ) {
        switch (type, option) {
        case (.secureCoreDisplay, .secureCoreOff):
            vpnGateway.changeActiveServerType(.standard)
            quickSettingsDisplayReconnectionFeedback()
            dismiss()

        case (.secureCoreDisplay, .secureCoreOn):
            vpnGateway.changeActiveServerType(.secureCore)
            quickSettingsDisplayReconnectionFeedback()
            dismiss()

        case (.killSwitchDisplay, .killSwitchOff):
            propertiesManager.killSwitch = false
            if vpnGateway.connection == .connected {
                log.info("Connection will restart after VPN feature change", category: .connectionConnect, event: .trigger, metadata: ["feature": "killSwitch"])
                vpnGateway.retryConnection()
            }
            dismiss()

        case (.killSwitchDisplay, .killSwitchOn):
            @Shared(.plutoniumFeature) var plutonium: PlutoniumFeatureToggle
            propertiesManager.killSwitch = true
            appFeaturePropertyProvider.setValue(ExcludeLocalNetworks.off)
            $plutonium.withLock { $0 = .disabled(plutonium.mode) }
            if vpnGateway.connection == .connected {
                log.info("Connection will restart after VPN feature change", category: .connectionConnect, event: .trigger, metadata: ["feature": "killSwitch"])
                vpnGateway.retryConnection()
            }
            dismiss()

        case let (.netShieldDisplay, .netShield(level)):
            quickSettingsChangeNetShieldLevel(level)
            dismiss()

        case (.portForwardingDisplay, .portForwardingOff):
            portForwardingPropertyProvider.setPortForwarding(false)
            switch quickSettingsVpnManager.currentVpnProtocol {
            case .wireGuard:
                log.info("Send feature to the local agent", category: .connectionConnect, event: .trigger, metadata: ["feature": "portForwarding"])
                quickSettingsVpnManager.set(portForwarding: false)
                quickSettingsVpnManager.stopNATPortMappingService()
            case .ike:
                if vpnGateway.connection == .connected {
                    log.info("Connection will restart after VPN feature change", category: .connectionConnect, event: .trigger, metadata: ["feature": "portForwarding"])
                    vpnGateway.retryConnection()
                }
            default:
                assertionFailure("not supported protocol in port forwarding presenter")
            }
            dismiss()

        case (.portForwardingDisplay, .portForwardingOn):
            portForwardingPropertyProvider.setPortForwarding(true)
            switch quickSettingsVpnManager.currentVpnProtocol {
            case .wireGuard:
                log.info("Send feature to the local agent", category: .connectionConnect, event: .trigger, metadata: ["feature": "portForwarding"])
                quickSettingsVpnManager.set(portForwarding: true)
                if vpnGateway.connection == .connected {
                    quickSettingsVpnManager.startNATPortMappingService()
                }
            case .ike:
                if vpnGateway.connection == .connected {
                    log.info("Connection will restart after VPN feature change", category: .connectionConnect, event: .trigger, metadata: ["feature": "portForwarding"])
                    vpnGateway.retryConnection()
                }
            default:
                assertionFailure("not supported protocol in port forwarding presenter")
            }
            dismiss()

        default:
            dismiss()
        }
    }

    private func quickSettingsDisplayReconnectionFeedback() {
        guard vpnGateway.connection == .connected else { return }
        log.debug("Reconnection requested by changing quick setting", category: .connectionConnect, event: .trigger)
        guard let countryCode = appStateManager.activeConnection()?.server.countryCode else {
            vpnGateway.quickConnect(trigger: .auto)
            return
        }
        vpnGateway.connectTo(serverGroup: .country(code: countryCode), ofType: .unspecified, trigger: .country)
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.25) {
            guard self.vpnGateway.connection == .connected else { return }
            log.debug("VPNGateway didn't finalize the connection in 0.25 seconds, using quick connect now", category: .connectionConnect, event: .trigger)
            self.vpnGateway.quickConnect(trigger: .country)
        }
    }

    private func quickSettingsChangeNetShieldLevel(_ level: NetShieldType) {
        vpnStateConfiguration.getInfoSync { [weak self] info in
            guard let self else { return }
            switch VpnFeatureChangeState(state: info.state, vpnProtocol: info.connection?.vpnProtocol) {
            case .withConnectionUpdate:
                netShieldPropertyProvider.setNetShieldType(level)
                quickSettingsVpnManager.set(netShieldType: level)
            case .withReconnect:
                netShieldPropertyProvider.setNetShieldType(level)
                log.info("Connection will restart after VPN feature change", category: .connectionConnect, event: .trigger, metadata: ["feature": "netShieldType"])
                vpnGateway.reconnect(with: netShieldPropertyProvider.getNetShieldType())
            case .immediate:
                netShieldPropertyProvider.setNetShieldType(level)
            }
        }
    }
}
