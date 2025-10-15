//
//  LocalAgentConfiguration.swift
//  ProtonVPN - Created on 2020-10-21.
//
//  Copyright (c) 2021 Proton Technologies AG
//
//  This file is part of ProtonVPN.
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
//

import Foundation

import Dependencies

import Domain
import VPNShared

public struct LocalAgentConfiguration {
    let hostname: String
    let features: VPNConnectionFeatures

    init(
        hostname: String,
        netshield: NetShieldType,
        vpnAccelerator: Bool,
        bouncing: String?,
        natType: NATType,
        safeMode: Bool?,
        portForwarding: Bool?
    ) {
        self.hostname = hostname
        self.features = VPNConnectionFeatures(
            netshield: netshield,
            vpnAccelerator: vpnAccelerator,
            bouncing: bouncing,
            natType: natType,
            safeMode: safeMode,
            portForwarding: portForwarding
        )
    }
}

extension LocalAgentConfiguration {
    init(configuration: VpnManagerConfiguration) {
        self.init(
            hostname: configuration.hostname,
            netshield: configuration.netShield,
            vpnAccelerator: configuration.vpnAccelerator,
            bouncing: configuration.bouncing,
            natType: configuration.natType,
            safeMode: configuration.safeMode,
            portForwarding: configuration.portForwarding
        )
    }

    init?(
        vpnProtocol: VpnProtocol?
    ) {
        @Dependency(\.propertiesManager) var propertiesManager
        guard let vpnProtocol, let connectionConfiguration = propertiesManager.currentConnectionConfiguration(for: vpnProtocol) else {
            return nil
        }

        @Dependency(\.appFeaturePropertyProvider) var appFeaturePropertyProvider
        @Dependency(\.natTypePropertyProvider) var natTypePropertyProvider
        @Dependency(\.portForwardingPropertyProvider) var portForwardingPropertyProvider
        @Dependency(\.netShieldPropertyProvider) var netShieldPropertyProvider
        @Dependency(\.safeModePropertyProvider) var safeModePropertyProvider

        self.init(
            hostname: connectionConfiguration.serverIp.domain,
            netshield: netShieldPropertyProvider.netShieldType,
            vpnAccelerator: appFeaturePropertyProvider.getValue(for: VPNAccelerator.self) == .on,
            bouncing: connectionConfiguration.serverIp.label,
            natType: natTypePropertyProvider.natType,
            safeMode: safeModePropertyProvider.safeMode,
            portForwarding: portForwardingPropertyProvider.portForwarding
        )
    }
}

// MARK: - LocalAgentConfiguration.Features

extension VPNConnectionFeatures {
    init?(
        vpnProtocol: VpnProtocol?
    ) {
        @Dependency(\.propertiesManager) var propertiesManager
        guard let vpnProtocol, let connectionConfiguration = propertiesManager.currentConnectionConfiguration(for: vpnProtocol) else {
            return nil
        }

        @Dependency(\.appFeaturePropertyProvider) var appFeaturePropertyProvider
        @Dependency(\.natTypePropertyProvider) var natTypePropertyProvider
        @Dependency(\.portForwardingPropertyProvider) var portForwardingPropertyProvider
        @Dependency(\.netShieldPropertyProvider) var netShieldPropertyProvider
        @Dependency(\.safeModePropertyProvider) var safeModePropertyProvider

        self.init(
            netshield: netShieldPropertyProvider.netShieldType,
            vpnAccelerator: appFeaturePropertyProvider.getValue(for: VPNAccelerator.self) == .on,
            bouncing: connectionConfiguration.serverIp.label,
            natType: natTypePropertyProvider.natType,
            safeMode: safeModePropertyProvider.safeMode,
            portForwarding: portForwardingPropertyProvider.portForwarding
        )
    }
}

// MARK: - PropertiesManagerProtocol

private extension PropertiesManagerProtocol {
    func currentConnectionConfiguration(for vpnProtocol: VpnProtocol) -> ConnectionConfiguration? {
        let configuration: ConnectionConfiguration? = switch vpnProtocol {
        case .ike:
            lastIkeConnection
        case .openVpn:
            lastOpenVpnConnection
        case .wireGuard:
            lastWireguardConnection
        }
        return configuration
    }
}
