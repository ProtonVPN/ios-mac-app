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
    public let city: String?

    public init(serverModelId: String, serverIPId: String, vpnProtocol: VpnProtocol, natType: NATType, safeMode: Bool?, feature: ServerFeature, city: String?) {
        self.serverModelId = serverModelId
        self.serverIPId = serverIPId
        self.vpnProtocol = vpnProtocol
        self.natType = natType
        self.safeMode = safeMode
        self.feature = feature
        self.city = city
    }
}

public extension DependencyValues {
    var watchVPNConnectionStatus: @Sendable () async -> AsyncStream<VPNConnectionStatus> {
        get { self[WatchAppStateChangesKey.self] }
        set { self[WatchAppStateChangesKey.self] = newValue }
    }
}

public enum WatchAppStateChangesKey: DependencyKey {
    public static let liveValue: @Sendable () async -> AsyncStream<VPNConnectionStatus> = {
#if !targetEnvironment(simulator)
        // Without `#if targetEnvironment(simulator)` SwiftUI previews crash
        assert(false, "Override this dependency!")
#endif
        // Actual implementation sits in the app, to reduce the scope of thing this library depends on
        return AsyncStream<VPNConnectionStatus> { _ in }
    }
}
