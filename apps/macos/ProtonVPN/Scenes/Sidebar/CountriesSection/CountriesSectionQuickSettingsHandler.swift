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

import Connection
import Dependencies
import Domain
import Foundation
import LegacyCommon
import NetShield
import Sharing
import VPNAppCore
import VPNShared

final class CountriesSectionQuickSettingsHandler {
    @Dependency(\.propertiesManager) private var propertiesManager
    @Dependency(\.portForwardingPropertyProvider) private var portForwardingPropertyProvider
    @Dependency(\.netShieldPropertyProvider) private var netShieldPropertyProvider
    @Dependency(\.appFeaturePropertyProvider) private var appFeaturePropertyProvider
    @Dependency(\.vpnStateConfiguration) private var vpnStateConfiguration
    @Dependency(\.sidebarConnectionCommandClient) private var sidebarConnectionCommandClient
    @Shared(.connectionState) private var connectionState: ConnectionState
    @Shared(.vpnConnectionStatus) private var vpnConnectionStatus: VPNConnectionStatus
    @Shared(.secureCoreToggle) private var secureCoreToggle: Bool

    private let quickSettingsVpnManager: VpnManagerProtocol

    private var isConnected: Bool {
        vpnConnectionStatus.isConnected(using: connectionState)
    }

    init(vpnManager: VpnManagerProtocol) {
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
            $secureCoreToggle.withLock { $0 = false }
            quickSettingsDisplayReconnectionFeedback()
            dismiss()

        case (.secureCoreDisplay, .secureCoreOn):
            $secureCoreToggle.withLock { $0 = true }
            quickSettingsDisplayReconnectionFeedback()
            dismiss()

        case (.killSwitchDisplay, .killSwitchOff):
            propertiesManager.killSwitch = false
            if isConnected {
                log.info("Connection will restart after VPN feature change", category: .connectionConnect, event: .trigger, metadata: ["feature": "killSwitch"])
                sidebarConnectionCommandClient.send(.retry)
            }
            dismiss()

        case (.killSwitchDisplay, .killSwitchOn):
            @Shared(.plutoniumFeature) var plutonium: PlutoniumFeatureToggle
            propertiesManager.killSwitch = true
            appFeaturePropertyProvider.setValue(ExcludeLocalNetworks.off)
            $plutonium.withLock { $0 = .disabled(plutonium.mode) }
            if isConnected {
                log.info("Connection will restart after VPN feature change", category: .connectionConnect, event: .trigger, metadata: ["feature": "killSwitch"])
                sidebarConnectionCommandClient.send(.retry)
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
                if isConnected {
                    log.info("Connection will restart after VPN feature change", category: .connectionConnect, event: .trigger, metadata: ["feature": "portForwarding"])
                    sidebarConnectionCommandClient.send(.retry)
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
                if isConnected {
                    quickSettingsVpnManager.startNATPortMappingService()
                }
            case .ike:
                if isConnected {
                    log.info("Connection will restart after VPN feature change", category: .connectionConnect, event: .trigger, metadata: ["feature": "portForwarding"])
                    sidebarConnectionCommandClient.send(.retry)
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
        guard vpnConnectionStatus.isConnected(using: connectionState) else { return }
        log.debug("Reconnection requested by changing quick setting", category: .connectionConnect, event: .trigger)
        let connectedCountryCode = vpnConnectionStatus.mergedServer(using: connectionState)?.logical.exitCountryCode
        let (spec, intent): (ConnectionSpec, UserInitiatedVPNChange.VPNTrigger) = if let countryCode = connectedCountryCode {
            (ConnectionSpec(location: .country(code: countryCode, order: .fastest), features: []), .country)
        } else {
            (ConnectionSpec(location: .any(.fastest), features: []), .auto)
        }
        sidebarConnectionCommandClient.send(.connect(spec, nil, intent))
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
                sidebarConnectionCommandClient.send(.retry)
            case .immediate:
                netShieldPropertyProvider.setNetShieldType(level)
            }
        }
    }
}
