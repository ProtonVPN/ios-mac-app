//
//  Created on 10/12/2024.
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

import Dependencies
import DependenciesMacros
import Domain
import Foundation
import Sharing
import VPNAppCore

@DependencyClient
public struct ConnectionFeatureProvider: Sendable {
    public internal(set) var connectionFeatures: @Sendable () -> VPNConnectionFeatures = { .unimplementedFeatures }
    public internal(set) var tunnelFeatures: @Sendable () -> TunnelFeatures = { .unimplementedFeatures }
    public internal(set) var connectionProtocol: @Sendable () -> ConnectionProtocol = { .smartProtocol }
}

extension ConnectionFeatureProvider: DependencyKey {
    #if !os(tvOS)
        public static let liveValue: ConnectionFeatureProvider = .init(
            connectionFeatures: {
                @Dependency(\.natTypePropertyProvider) var natTypePropertyProvider
                @Dependency(\.portForwardingPropertyProvider) var portForwardingPropertyProvider
                @Dependency(\.netShieldPropertyProvider) var netShieldPropertyProvider

                return .init(
                    netshield: netShieldPropertyProvider.getNetShieldType(),
                    vpnAccelerator: AuthorizedFeatureValue<VPNAccelerator>().value() == .on,
                    natType: natTypePropertyProvider.getNATType(),
                    portForwarding: portForwardingPropertyProvider.getPortForwarding()
                )
            },
            tunnelFeatures: {
                @Shared(.killSwitch) var killSwitch
                return TunnelFeatures(
                    killSwitch: killSwitch,
                    excludeLocalNetworks: AuthorizedFeatureValue<ExcludeLocalNetworks>().value() == .on
                )
            },
            connectionProtocol: {
                @Shared(.connectionProtocol) var connectionProtocol
                return connectionProtocol
            }
        )
    #else
        public static let liveValue: ConnectionFeatureProvider = .init(
            connectionFeatures: { .defaultFeatures },
            tunnelFeatures: { .tvFeatures },
            connectionProtocol: { .vpnProtocol(.wireGuard(.udp)) }
        )
    #endif

    public static let testValue: ConnectionFeatureProvider = .init()
}

public extension DependencyValues {
    var connectionFeatureProvider: ConnectionFeatureProvider {
        get { self[ConnectionFeatureProvider.self] }
        set { self[ConnectionFeatureProvider.self] = newValue }
    }
}

extension VPNConnectionFeatures {
    @usableFromInline static let unimplementedFeatures: VPNConnectionFeatures = .init(
        netshield: .off,
        vpnAccelerator: false,
        natType: .moderateNAT,
        portForwarding: false
    )

    #if os(tvOS)
        @usableFromInline static let defaultFeatures: VPNConnectionFeatures = .init(
            netshield: .level1,
            vpnAccelerator: true,
            natType: .moderateNAT,
            portForwarding: false
        )
    #endif
}

extension TunnelFeatures {
    @usableFromInline static let unimplementedFeatures: TunnelFeatures = {
        #if !os(tvOS)
            .init(killSwitch: false, excludeLocalNetworks: false)
        #else
            .tvFeatures
        #endif
    }()
}
