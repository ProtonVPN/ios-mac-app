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

import struct Domain.VPNServer
import struct Domain.ConnectionSpec

enum TunnelConfigurationOperation {
    case connection(VPNServer)
    case disconnection
}

struct ManagerConfigurator: Sendable {
    private var configure: @Sendable (inout TunnelProviderManager, TunnelConfigurationOperation) async throws -> Void

    init(configure: @escaping @Sendable (inout TunnelProviderManager, TunnelConfigurationOperation) async throws -> Void) {
        self.configure = configure
    }

    func configure(_ manager: inout TunnelProviderManager, for operation: TunnelConfigurationOperation) async throws {
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
