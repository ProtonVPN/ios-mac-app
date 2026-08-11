//
//  Created on 29/05/2024.
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

import let CoreConnection.log
import Dependencies
import Domain
import Foundation
import class NetworkExtension.NETunnelProviderProtocol

public enum TunnelConfigurationOperation {
    case connection(ServerConnectionIntent)
    /// An in-place configuration update, recorded into NE preferences before it is sent to the WireGuard extension.
    case update(ConnectionUpdate)
    /// Prepares a manager for stopping its tunnel, and disables on-demand so the OS doesn't reconnect. Used for both
    /// WireGuard and IKEv2.
    case disconnection
    /// Declares which file the extension should write a packet capture into, or `nil` to withdraw the request. A tunnel
    /// that starts later reads this from its own configuration.
    case packetCapture(fileURL: URL?)
    #if !os(tvOS)
        /// Build/start a zero-peer ProTUN tunnel with no server, used to enforce Advanced kill switch
        /// blocking from a fully disconnected state. The tunnel intercepts all traffic and never
        /// reaches a real peer, so it blocks until reconfigured/torn down
        case zeroPeerColdStart
    #endif
}

package struct ManagerConfigurator {
    public typealias ConfigurationHandler = @Sendable (inout TunnelProviderManager, TunnelConfigurationOperation) async throws -> Void

    public private(set) var changes: @Sendable (ServerConnectionIntent) throws -> ConnectionUpdate
    public private(set) var configure: ConfigurationHandler
}

/// Convenience API with labels
extension ManagerConfigurator {
    func configure(_ manager: inout TunnelProviderManager, for operation: TunnelConfigurationOperation) async throws {
        log.debug(
            "Configuring manager",
            category: .connection,
            metadata: ["manager": "\(manager)", "operation": ["\(operation)"]]
        )
        try await configure(&manager, operation)
    }
}

extension ManagerConfigurator: DependencyKey {
    package static let liveValue: Self = .wireGuardConfigurator
}

package extension DependencyValues {
    var tunnelProviderConfigurator: ManagerConfigurator {
        get { self[ManagerConfigurator.self] }
        set { self[ManagerConfigurator.self] = newValue }
    }
}
