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

@available(tvOS 17, *)
public struct ConnectionFeatureProvider: Sendable {
    public internal(set) var connectionFeatures: @Sendable () -> VPNConnectionFeatures
    public internal(set) var setConnectionFeatures: @Sendable (_: VPNConnectionFeatures) -> Void
    public internal(set) var tunnelFeatures: @Sendable () -> TunnelFeatures
    public internal(set) var connectionProtocol: @Sendable () -> ConnectionProtocol

    public init(
        connectionFeatures: @escaping @Sendable () -> VPNConnectionFeatures = { .unimplementedFeatures },
        setConnectionFeatures: @escaping @Sendable (_: VPNConnectionFeatures) -> Void = { _ in reportIssue() },
        tunnelFeatures: @escaping @Sendable () -> TunnelFeatures = { .unimplementedFeatures },
        connectionProtocol: @escaping @Sendable () -> ConnectionProtocol = { .smartProtocol }
    ) {
        self.connectionFeatures = connectionFeatures
        self.setConnectionFeatures = setConnectionFeatures
        self.tunnelFeatures = tunnelFeatures
        self.connectionProtocol = connectionProtocol
    }
}

extension ConnectionFeatureProvider: TestDependencyKey {
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
        bouncing: nil, // This is set to the target server's `label` property during connection
        natType: .moderateNAT,
        safeMode: false,
        portForwarding: false
    )
}

extension TunnelFeatures {
    @usableFromInline static let unimplementedFeatures: TunnelFeatures = {
        #if !os(tvOS)
            .init(killSwitch: false, excludeLocalNetworks: false)
        #else
            .init()
        #endif
    }()
}
