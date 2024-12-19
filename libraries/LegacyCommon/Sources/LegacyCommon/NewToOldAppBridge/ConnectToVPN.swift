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
    public static let liveValue = {
        let isRedesignEnabled = FeatureFlagsRepository.shared.isEnabled(VPNFeatureFlagType.redesigniOS)
        if isRedesignEnabled, #available(iOS 16, *) {
            return newConnect
        } else {
            return legacyConnect
        }
    }()

    @available(iOS 16, *)
    public static let newConnect: @Sendable (ConnectionSpec) async throws -> Void = { intent in
        @Dependency(\.connectionBridge) var bridge
        @Dependency(\.propertiesManager) var propertiesManager
        @Dependency(\.serverSelector) var serverSelector
        @Dependency(\.smartPortSelector) var portSelector
        @Dependency(\.vpnFeaturesProvider) var vpnFeaturesProvider
        @Dependency(\.appFeaturePropertyProvider) var featurePropertyProvider

        // Let's grab protocol information from PropertiesManager until redesigned settings are in place
        let acceptableProtocols: ProtocolSupport
        switch propertiesManager.connectionProtocol {
        case .vpnProtocol(let vpnProtocol):
            acceptableProtocols = vpnProtocol.protocolSupport
        case .smartProtocol:
            acceptableProtocols = propertiesManager.smartProtocolConfig.supportedProtocols
                .reduce(.zero, { $0.union($1.protocolSupport) })
        }

        let server = try serverSelector.select(intent, acceptableProtocols)
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
            transport: .udp,
            ports: ports,
            tunnelFeatures: TunnelFeatures(
                killSwitch: propertiesManager.killSwitch,
                excludeLocalNetworks: featurePropertyProvider.getValue(for: ExcludeLocalNetworks.self) == .on
            )
        )
        let intent = ServerConnectionIntent(server: server, tunnelSettings: tunnelSettings, features: features)
        // VPNAPPL-2506: choose protocol and port for smart protocol

        bridge.push(intent: ConnectionFeature.Action.connect(intent))
    }

    /// Bridges new connection dependency with the legacy connection layer
    public static let legacyConnect: @Sendable (ConnectionSpec) async throws -> Void = { intent in
        @Dependency(\.siriHelper) var siriHelper
        siriHelper().donateQuickConnect() // Change to more concrete donation when refactoring Siri stuff

        do {
            let gateway = Container.sharedContainer.makeVpnGateway2()
            try await gateway.connect(withIntent: intent)

            let propertyManager = Container.sharedContainer.makePropertiesManager()
            propertyManager.lastConnectionIntent = intent

        } catch VpnGateway2.GatewayError.noServerFound {
            log.error("No server found", metadata: ["intent": "\(intent)"])
            throw VpnGateway2.GatewayError.noServerFound // Not sure

        } catch VpnGateway2.GatewayError.resolutionUnavailable(let forSpecificCountry, let type, let reason) {
            log.warning("Server resolution unavailable", category: .connectionConnect, metadata: ["forSpecificCountry": "\(forSpecificCountry)", "type": "\(type)", "reason": "\(reason)", "intent": "\(intent)"])

//            Code from serverTierChecker.notifyResolutionUnavailable(forSpecificCountry: forSpecificCountry, type: type, reason: reason)
            @Dependency(\.pushAlert) var alert

            switch reason {
            case .upgrade:
                alert(AllCountriesUpsellAlert())
            case .maintenance:
                alert(MaintenanceAlert(forSpecificCountry: forSpecificCountry))
            case .protocolNotSupported:
                alert(ProtocolNotAvailableForServerAlert())
            case .locationNotFound(let profileName):
                alert(LocationNotAvailableAlert(profileName: profileName))
            }
        }
    }

    enum ConnectionError: Error {
        case unexpectedProtocol(VpnProtocol)
    }
}
