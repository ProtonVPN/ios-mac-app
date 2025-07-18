//
//  Created on 17/12/2024.
//
//  Copyright (c) 2024 Proton AG
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

import CoreConnection
import Dependencies
import Domain

// In an ideal world, ``VPNConnectionFeaturesProvider`` being defined in ``Connection``, its implementation
// would also being defined there. But for the moment, it's defined here and we'll leverage
// ``AppFeaturePropertyProvider`` and others to manage the features.
extension ConnectionFeatureProvider: @retroactive DependencyKey {
    public static let liveValue: ConnectionFeatureProvider = .init(
        connectionFeatures: {
            @Dependency(\.appFeaturePropertyProvider) var featurePropertyProvider

            let netShieldPropertyProvider: any NetShieldPropertyProvider = NetShieldPropertyProviderImplementation()
            let natTypePropertyProvider: any NATTypePropertyProvider = NATTypePropertyProviderImplementation()
            let safeModePropertyProvider: any SafeModePropertyProvider = SafeModePropertyProviderImplementation()
            let portForwardingPropertyProvider: any PortForwardingPropertyProvider = PortForwardingPropertyProviderImplementation()

            return .init(
                netshield: netShieldPropertyProvider.netShieldType,
                vpnAccelerator: featurePropertyProvider.getValue(for: VPNAccelerator.self).isOn,
                bouncing: nil, // VPNAPPL-2561: how to properly handle this?
                natType: natTypePropertyProvider.natType,
                safeMode: safeModePropertyProvider.safeMode,
                portForwarding: portForwardingPropertyProvider.portForwarding
            )
        },
        setConnectionFeatures: { newFeatures in
            @Dependency(\.appFeaturePropertyProvider) var featurePropertyProvider

            var netShieldPropertyProvider: any NetShieldPropertyProvider = NetShieldPropertyProviderImplementation()
            var natTypePropertyProvider: any NATTypePropertyProvider = NATTypePropertyProviderImplementation()
            var safeModePropertyProvider: any SafeModePropertyProvider = SafeModePropertyProviderImplementation()

            netShieldPropertyProvider.netShieldType = newFeatures.netshield
            natTypePropertyProvider.natType = newFeatures.natType
            safeModePropertyProvider.safeMode = newFeatures.safeMode
        },
        tunnelFeatures: {
            @Dependency(\.propertiesManager) var propertiesManager
            @Dependency(\.appFeaturePropertyProvider) var featurePropertyProvider
            return TunnelFeatures(
                killSwitch: propertiesManager.killSwitch,
                excludeLocalNetworks: featurePropertyProvider.getValue(for: ExcludeLocalNetworks.self) == .on
            )
        },
        connectionProtocol: {
            @Dependency(\.propertiesManager) var propertiesManager
            return propertiesManager.connectionProtocol
        }
    )
}

private extension VPNAccelerator {
    var isOn: Bool {
        self == .on
    }
}
