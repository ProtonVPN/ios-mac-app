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

public struct ConnectionConfigurer: TestDependencyKey {
    public var featureChangeAvailability: @Sendable (ConnectionFeatureChange) -> FeatureChangeAvailability
    public var reconnect: @Sendable (Set<ConnectionFeatureChange.TunnelFeature>) -> Void
    public var update: @Sendable (Set<ConnectionFeatureChange.AgentFeature>) -> Void

    public init(
        featureChangeAvailability: @escaping @Sendable (ConnectionFeatureChange) -> FeatureChangeAvailability,
        reconnect: @escaping @Sendable (Set<ConnectionFeatureChange.TunnelFeature>) -> Void,
        update: @escaping @Sendable (Set<ConnectionFeatureChange.AgentFeature>) -> Void
    ) {
        self.featureChangeAvailability = featureChangeAvailability
        self.reconnect = reconnect
        self.update = update
    }

    public static let testValue = ConnectionConfigurer(
        featureChangeAvailability: { _ in .immediate },
        reconnect: { _ in },
        update: { _ in }
    )
}

extension DependencyValues {
    public var connectionConfigurer: ConnectionConfigurer {
        get { self[ConnectionConfigurer.self] }
        set { self[ConnectionConfigurer.self] = newValue }
    }
}


public enum FeatureChangeAvailability: Equatable {
    case immediate
    case withConnectionUpdate
    case withReconnect
}
