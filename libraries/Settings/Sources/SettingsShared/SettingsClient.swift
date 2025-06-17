//
//  Created on 22/01/2025.
//
//  Copyright (c) 2025 Proton AG
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

public struct SettingsClient: TestDependencyKey, Sendable {
    public private(set) var isActive: @Sendable () -> Bool
    public private(set) var featureChangeAvailability: @Sendable (ConnectionFeatureChange) -> FeatureChangeAvailability
    public private(set) var protocolChangeAvailability: @Sendable (ConnectionProtocol) -> ProtocolChangeAvailability
    public private(set) var disconnect: @Sendable () async throws -> Void
    public private(set) var reconnect: @Sendable (Set<ConnectionFeatureChange.TunnelFeature>) async throws -> Void
    // Normally @MainActor implies @Sendable but compiler is somewhat unhappy anyway so let's have both annotations
    public private(set) var update: @Sendable @MainActor (Set<ConnectionFeatureChange.AgentFeature>) -> Void

    public init(
        isActive: @escaping @Sendable () -> Bool,
        featureChangeAvailability: @escaping @Sendable (ConnectionFeatureChange) -> FeatureChangeAvailability,
        protocolChangeAvailability: @escaping @Sendable (ConnectionProtocol) -> ProtocolChangeAvailability,
        disconnect: @escaping @Sendable () async throws -> Void,
        reconnect: @escaping @Sendable (Set<ConnectionFeatureChange.TunnelFeature>) async throws -> Void,
        update: @escaping @Sendable @MainActor (Set<ConnectionFeatureChange.AgentFeature>) -> Void
    ) {
        self.isActive = isActive
        self.featureChangeAvailability = featureChangeAvailability
        self.protocolChangeAvailability = protocolChangeAvailability
        self.disconnect = disconnect
        self.reconnect = reconnect
        self.update = update
    }

    public static let testValue = SettingsClient(
        isActive: { false },
        featureChangeAvailability: { _ in .immediate },
        protocolChangeAvailability: { _ in .immediate },
        disconnect: {},
        reconnect: { _ in },
        update: { _ in }
    )
}

public extension DependencyValues {
    var settingsClient: SettingsClient {
        get { self[SettingsClient.self] }
        set { self[SettingsClient.self] = newValue }
    }
}

public enum FeatureChangeAvailability: Sendable, Equatable {
    case immediate
    case withConnectionUpdate
    case withReconnect
}

public enum ProtocolChangeAvailability: Sendable, Equatable {
    case immediate
    case withReconnect
    case protocolUnavailable // currently connected server doesn't support the new protocol
}
