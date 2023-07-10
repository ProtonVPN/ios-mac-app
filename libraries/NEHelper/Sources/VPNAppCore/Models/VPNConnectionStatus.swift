//
//  Created on 2023-06-14.
//
//  Copyright (c) 2023 Proton AG
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
import Foundation
import Combine
import VPNShared

// This struct is still WIP
public enum VPNConnectionStatus: Equatable {

    case disconnected
    
    case connected(ConnectionSpec, VPNConnectionActual?)

    case connecting(ConnectionSpec, VPNConnectionActual?)

    case loadingConnectionInfo(ConnectionSpec, VPNConnectionActual?)

    case disconnecting(ConnectionSpec, VPNConnectionActual?)

}

public struct VPNConnectionActual: Equatable {
    public let serverModelId: String
    public let serverIPId: String
    public let vpnProtocol: VpnProtocol
    public let natType: NATType
    public let safeMode: Bool?
    public let feature: ServerFeature
    public let serverName: String
    public let country: String
    public let city: String?

    public init(serverModelId: String, serverIPId: String, vpnProtocol: VpnProtocol, natType: NATType, safeMode: Bool?, feature: ServerFeature, serverName: String, country: String, city: String?) {
        self.serverModelId = serverModelId
        self.serverIPId = serverIPId
        self.vpnProtocol = vpnProtocol
        self.natType = natType
        self.safeMode = safeMode
        self.feature = feature
        self.serverName = serverName
        self.country = country
        self.city = city
    }
}

// MARK: - Watch for changes

public extension DependencyValues {
    var vpnConnectionStatusPublisher: @Sendable () -> AnyPublisher<VPNConnectionStatus, Never> {
        get { self[VPNConnectionStatusPublisherKey.self] }
        set { self[VPNConnectionStatusPublisherKey.self] = newValue }
    }
}

public enum VPNConnectionStatusPublisherKey: DependencyKey {
    public static let liveValue: @Sendable () -> AnyPublisher<VPNConnectionStatus, Never> = {
#if !targetEnvironment(simulator)
        // Without `#if targetEnvironment(simulator)` SwiftUI previews crash
        assert(false, "Override this dependency!")
#endif
        // Actual implementation sits in the app, to reduce the scope of thing this library depends on
        return Empty<VPNConnectionStatus, Never>().eraseToAnyPublisher()
    }
}
