//
//  Created on 09/01/2025.
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

import Foundation
import ComposableArchitecture
import VPNAppCore
import Domain

extension ConnectionIntentStorage: DependencyKey {
    public static let storageKey: String = "ServerConnectionIntent"

    public static let liveValue = ConnectionIntentStorage(getConnectionIntent: {
        @Dependency(\.storage) var storage
        if let intent = try storage.getForUser(ServerConnectionIntent.self, forKey: Self.storageKey) {
            return intent
        }

        // This should only happen for the duration of a connection made in the legacy connection layer
        // Subsequent connections initiated by the ConnectionFeature should have their intent saved under `storageKey`
        log.warning("Constructing original connection intent from legacy connection properties")
        @Dependency(\.propertiesManager) var propertiesManager
        guard let lastWGConfig = propertiesManager.lastWireguardConnection else {
            throw LegacyIntentRetrievalFailure.missingWireguardConfig
        }
        guard let lastConnectionRequest = propertiesManager.lastConnectionRequest else {
            throw LegacyIntentRetrievalFailure.missingConnectionRequest
        }
        let legacySpec = ConnectionSpec(connectionRequest: lastConnectionRequest)
        let legacyLogical = VPNServer(legacyModel: lastWGConfig.server).logical
        let legacyEndpoint = ServerEndpoint(legacyModel: lastWGConfig.serverIp)
        let legacyServer = Server(logical: legacyLogical, endpoint: legacyEndpoint)
        let legacyFeatures = lastWGConfig.ports

        guard case .wireGuard(let transport) = lastWGConfig.vpnProtocol else {
            throw LegacyIntentRetrievalFailure.unexpectedProtocol(lastWGConfig.vpnProtocol)
        }
        // TunnelFeatures are not currently used by a consumer of `getConnectionIntent`
        let tunnelFeatures = TunnelFeatures(killSwitch: false, excludeLocalNetworks: false)
        let tunnelSettings = TunnelSettings(transport: transport, ports: lastWGConfig.ports, tunnelFeatures: tunnelFeatures)
        @Dependency(\.vpnFeaturesProvider) var featuresProvider
        let features = featuresProvider.connectionFeatures()
        let legacyIntent = ServerConnectionIntent(spec: legacySpec, server: legacyServer, tunnelSettings: tunnelSettings, features: features)
        try storage.setForUser(legacyIntent, forKey: Self.storageKey)
        return legacyIntent

    }, set: { newIntent in
        @Dependency(\.storage) var storage
        try storage.setForUser(newIntent, forKey: Self.storageKey)
    })
}

enum LegacyIntentRetrievalFailure: Error {
    case missingWireguardConfig
    case missingConnectionRequest
    case unexpectedProtocol(VpnProtocol)
}
