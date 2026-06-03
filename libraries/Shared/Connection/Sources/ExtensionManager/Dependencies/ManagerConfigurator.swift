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
    // This could be a set, but involves plumbing a lot of types to be Hashable
    case reconfiguration([ConnectionChange])
}

struct ManagerConfigurator {
    typealias ConfigurationHandler = @Sendable (inout TunnelProviderManager, TunnelConfigurationOperation) async throws -> Void

    private(set) var changes: @Sendable (ServerConnectionIntent) -> Set<ConnectionChange>
    private(set) var configure: ConfigurationHandler
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
    static let liveValue: Self = .wireGuardConfigurator
}

extension DependencyValues {
    var tunnelProviderConfigurator: ManagerConfigurator {
        get { self[ManagerConfigurator.self] }
        set { self[ManagerConfigurator.self] = newValue }
    }
}
