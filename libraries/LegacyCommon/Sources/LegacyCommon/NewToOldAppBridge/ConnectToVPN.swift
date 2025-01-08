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

import ComposableArchitecture
import ProtonCoreFeatureFlags
import Connection
import Persistence
import Domain
import VPNAppCore

extension ConnectToVPNKey: DependencyKey {
    enum ConnectionError: Error {
        case unexpectedProtocol(VpnProtocol)
    }

    private static var isEnabled: Bool {
        let ffRepository = FeatureFlagsRepository.shared
        return ffRepository.isEnabled(VPNFeatureFlagType.redesigniOS) || ffRepository.isEnabled(VPNFeatureFlagType.useConnectionFeature)
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
        @Dependency(\.propertiesManager) var propertiesManager
        @Dependency(\.serverSelector) var serverSelector
        @Dependency(\.smartPortSelector) var portSelector
        @Dependency(\.vpnFeaturesProvider) var vpnFeaturesProvider
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

        let portSelectionResult = try await portSelector.select(
            endpoint: server.endpoint,
            connectionProtocol: propertiesManager.connectionProtocol
        )
        guard case .wireGuard(let transport) = portSelectionResult.chosenProtocol else {
            throw ConnectionError.unexpectedProtocol(portSelectionResult.chosenProtocol)
        }
        let ports = portSelectionResult.ports
        log.info("WG transport and ports selected", category: .connection, metadata: ["transport": "\(transport)", "port": "\(ports)"])

        let features = vpnFeaturesProvider.connectionFeatures()
        let tunnelSettings = TunnelSettings(
            transport: transport,
            ports: ports,
            tunnelFeatures: TunnelFeatures(
                killSwitch: propertiesManager.killSwitch,
                excludeLocalNetworks: featurePropertyProvider.getValue(for: ExcludeLocalNetworks.self) == .on
            )
        )
        let intent = ServerConnectionIntent(spec: spec, server: server, tunnelSettings: tunnelSettings, features: features)
        @Dependency(\.connectionIntentStorage) var storage
        try storage.set(connectionIntent: intent)

        bridge.push(intent: ConnectionFeature.Action.connect(intent))
    }
}
