//
//  Created on 19/12/2024.
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

import Foundation

public enum ProtocolConfiguration: Equatable, Sendable, Codable {
    case ike
    case wireGuard(WireGuardSettings)
}

public typealias TunnelSettings = WireGuardSettings
public struct WireGuardSettings: Equatable, Sendable, Codable {
    public let backend: WGBackend
    public let transport: WireGuardTransport?
    public let features: TunnelFeatures

    public init(backend: WGBackend, transport: WireGuardTransport?, features: TunnelFeatures) {
        self.backend = backend
        self.transport = transport
        self.features = features
    }
}

public enum TunnelProtocol: Equatable, Hashable, Sendable {
    case ike
    case wireGuard(WGBackend)

    package static var availableProtocols: [Self] {
        #if os(macOS)
            [.ike, .wireGuard(.proTUN)]
        #else
            [.wireGuard(.proTUN)]
        #endif
    }
}

public enum WGBackend: Equatable, Sendable, Codable {
    case go
    case proTUN
}
