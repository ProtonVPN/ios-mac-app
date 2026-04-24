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
    public let transport: WireGuardTransport
    public let ports: [Int]
    public let features: TunnelFeatures

    public init(backend: WGBackend, transport: WireGuardTransport, ports: [Int], features: TunnelFeatures) {
        self.backend = backend
        self.transport = transport
        self.ports = ports
        self.features = features
    }
}

public enum WGBackend: Equatable, Sendable, Codable {
    case go
    case proTUN
}
