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
    @Dependency(\.sidebarConnectionCommandClient) private var sidebarConnectionCommandClient
    @Shared(.connectionState) private var connectionState: ConnectionState
    @Shared(.vpnConnectionStatus) private var vpnConnectionStatus: VPNConnectionStatus
    @Shared(.secureCoreToggle) private var secureCoreToggle: Bool

    private var isConnected: Bool {
        connectionState.isConnected
    }

    private var isConnectionActive: Bool {
        switch connectionState {
        case .disconnected, .resolving:
            false
        case .connecting, .connected, .disconnecting:
            true
        }
    }

    init() {}

    var quickSettingsInitialNetShieldStats: NetShieldModel {
        .zero(enabled: false)
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
            quickSettingsChangePortForwarding(false)
            dismiss()

        case (.portForwardingDisplay, .portForwardingOn):
            quickSettingsChangePortForwarding(true)
            dismiss()

        default:
            dismiss()
        }
    }

    private func quickSettingsDisplayReconnectionFeedback() {
        guard connectionState.isConnected else { return }
        log.debug("Reconnection requested by changing quick setting", category: .connectionConnect, event: .trigger)
        let connectedCountryCode = vpnConnectionStatus.mergedServer(using: connectionState)?.logical.exitCountryCode
        let spec = SecureCoreConnectionSpecResolver.fastestSpec(
            secureCoreEnabled: secureCoreToggle,
            connectedExitCountryCode: connectedCountryCode
        )
        let intent = SecureCoreConnectionSpecResolver.reconnectTrigger(
            connectedExitCountryCode: connectedCountryCode
        )
        sidebarConnectionCommandClient.send(.connect(spec, nil, intent))
    }

    private func quickSettingsChangeNetShieldLevel(_ level: NetShieldType) {
        switch VpnFeatureChangeState(connectionState: connectionState, vpnConnectionStatus: vpnConnectionStatus) {
        case .withConnectionUpdate:
            netShieldPropertyProvider.setNetShieldType(level)
            let features: Set<ConnectionFeatureChange.AgentFeature> = [.netShield(level)]
            sidebarConnectionCommandClient.send(.applySettings(features))
        case .withReconnect:
            netShieldPropertyProvider.setNetShieldType(level)
            log.info("Connection will restart after VPN feature change", category: .connectionConnect, event: .trigger, metadata: ["feature": "netShieldType"])
            sidebarConnectionCommandClient.send(.retry)
        case .immediate:
            netShieldPropertyProvider.setNetShieldType(level)
        }
    }

    private func quickSettingsChangePortForwarding(_ isEnabled: Bool) {
        portForwardingPropertyProvider.setPortForwarding(isEnabled)
        switch VpnFeatureChangeState(connectionState: connectionState, vpnConnectionStatus: vpnConnectionStatus) {
        case .withConnectionUpdate:
            log.info("Send feature to the local agent", category: .connectionConnect, event: .trigger, metadata: ["feature": "portForwarding"])
            let features: Set<ConnectionFeatureChange.AgentFeature> = [.portForwarding(isEnabled)]
            sidebarConnectionCommandClient.send(.applySettings(features))
        case .withReconnect:
            if isConnectionActive {
                log.info("Connection will restart after VPN feature change", category: .connectionConnect, event: .trigger, metadata: ["feature": "portForwarding"])
                if let activeVpnProtocol = vpnConnectionStatus.mergedVpnProtocol(using: connectionState) {
                    sidebarConnectionCommandClient.send(.reconnect(.vpnProtocol(activeVpnProtocol)))
                } else {
                    sidebarConnectionCommandClient.send(.retry)
                }
            }
        case .immediate:
            break
        }
    }
}
