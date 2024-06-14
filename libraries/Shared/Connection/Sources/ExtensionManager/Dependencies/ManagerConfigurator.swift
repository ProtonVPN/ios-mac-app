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

import Foundation

import class NetworkExtension.NETunnelProviderProtocol

import Dependencies

import struct Domain.Server
import struct Domain.ConnectionSpec
import let ConnectionFoundations.log

enum TunnelConfigurationOperation {
    case connection(Server)
    case disconnection
}

struct ManagerConfigurator: Sendable {
    typealias ConfigurationHandler = (@Sendable (inout TunnelProviderManager, TunnelConfigurationOperation) async throws -> Void)

    private var configure: ConfigurationHandler

    init(configure: @escaping ConfigurationHandler) {
        self.configure = configure
    }
}

/// Convenience API with labels
extension ManagerConfigurator {
    func configure(_ manager: inout TunnelProviderManager, for operation: TunnelConfigurationOperation) async throws {
        log.debug("Configuring manager", category: .connection, metadata: ["manager": "\(manager)", "operation": ["\(operation)"]])
        try await configure(&manager, operation)
    }
}

extension ManagerConfigurator: DependencyKey {
    public static let liveValue: Self = .wireGuardConfigurator
}

extension DependencyValues {
    var tunnelProviderConfigurator: ManagerConfigurator {
        get { self[ManagerConfigurator.self] }
        set { self[ManagerConfigurator.self] = newValue }
    }
}
