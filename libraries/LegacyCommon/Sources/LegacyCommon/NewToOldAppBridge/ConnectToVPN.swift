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

import ProtonCoreFeatureFlags
import Connection
import Persistence
import Domain
import VPNAppCore

import protocol Foundation.LocalizedError

import ComposableArchitecture

extension ConnectToVPNKey: DependencyKey {
    enum ConnectionError: LocalizedError {
        case cancelled

        var errorDescription: String? {
            switch self {
            case .cancelled:
                return "Connection attempt cancelled"
            }
        }
    }

    private static var isEnabled: Bool {
        FeatureFlagsRepository.shared.isConnectionFeatureEnabled
    }

    public static let liveValue = {
        if Self.isEnabled, #available(iOS 16, *) {
            return newConnect
        } else {
            return legacyConnect
        }
    }()

    @available(iOS 16, *)
    static let newConnect: @Sendable (ConnectionSpec) async throws -> Void = { spec in
        // First, let's try to resolve the server we want to connect to.
        // This way we can avoid disconnecting if we are already connected and can't resolve the target server
        @Dependency(\.serverSelector) var serverSelector

        // Let's grab protocol information from PropertiesManager until redesigned settings are in place
        @Dependency(\.propertiesManager) var propertiesManager
        let acceptableProtocols: ProtocolSupport
        switch propertiesManager.connectionProtocol {
        case .vpnProtocol(let vpnProtocol):
            acceptableProtocols = vpnProtocol.protocolSupport
        case .smartProtocol:
            acceptableProtocols = propertiesManager.smartProtocolConfig.supportedProtocols
                .reduce(.zero, { $0.union($1.protocolSupport) })
        }

        @SharedReader(.userTier) var userTier: Int
        let server = try serverSelector.select(spec, userTier, acceptableProtocols)
        log.info("Server selected: \(server)", category: .connection)

        if Task.isCancelled { throw ConnectionError.cancelled }

        @Dependency(\.connectionBridge) var bridge
        bridge.push(intent: .connect(ConnectionPreparationIntent(spec: spec, server: server)))
    }
}
