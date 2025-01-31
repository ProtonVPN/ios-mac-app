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

        var errorDescription: String {
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
        @Dependency(\.connectionBridge) var bridge

        @SharedReader(.connectionState) var connectionState: ConnectionState?

        if connectionState.is(\.connected) {
            bridge.push(intent: ConnectionFeature.Action.disconnect(.userIntent))

            try await $connectionState.when(willBe: \.disconnected, every: .milliseconds(20), deadline: .seconds(2)) {
                try await prepareConnection(spec)
            }
        } else {
            try await prepareConnection(spec)
        }
    }

    @available(iOS 16, *)
    private static let prepareConnection: @Sendable (ConnectionSpec) async throws -> Void = { spec in
        @Dependency(\.connectionBridge) var bridge
        @Dependency(\.serverSelector) var serverSelector
        @Dependency(\.propertiesManager) var propertiesManager
        @Dependency(\.appFeaturePropertyProvider) var featurePropertyProvider

        @SharedReader(.userTier) var userTier: Int

        // Let's grab protocol information from PropertiesManager until redesigned settings are in place
        let acceptableProtocols: ProtocolSupport
        switch propertiesManager.connectionProtocol {
        case .vpnProtocol(let vpnProtocol):
            acceptableProtocols = vpnProtocol.protocolSupport
        case .smartProtocol:
            acceptableProtocols = propertiesManager.smartProtocolConfig.supportedProtocols
                .reduce(.zero, { $0.union($1.protocolSupport) })
        }

        let server = try serverSelector.select(spec, userTier, acceptableProtocols)
        log.info("Server selected: \(server)", category: .connection)

        guard !Task.isCancelled else {
            throw ConnectionError.cancelled
        }

        let connectionProtocol = propertiesManager.connectionProtocol

        let tunnelFeatures = TunnelFeatures(
            killSwitch: propertiesManager.killSwitch,
            excludeLocalNetworks: featurePropertyProvider.getValue(for: ExcludeLocalNetworks.self) == .on
        )

        bridge.push(intent: ConnectionFeature.Action.preparation(spec, server, connectionProtocol, tunnelFeatures))
    }
}
