//
//  Created on 2023-06-20.
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

import Foundation

import Dependencies

import Domain
import VPNShared
import VPNAppCore

public protocol VpnGatewayProtocol2 {
    func connect(withIntent: ConnectionSpec) async throws
    func disconnect() async throws
}

public protocol VpnGateway2Factory {
    func makeVpnGateway2() -> VpnGatewayProtocol2
}

/// More or less temporary class before we get to refactoring whole VPN connection management.
/// It still uses `AppStateManager` but doesn't have complexity of original `VpnGateway`.
/// Some of the features of `VpnGateway` should be moved to other places.
public class VpnGateway2: VpnGatewayProtocol2 {

    private let appStateManager: AppStateManager
    private let serverStorage: ServerStorage
    private let propertiesManager: PropertiesManagerProtocol
    private let serverTierChecker: ServerTierChecker
    private let availabilityCheckerResolverFactory: AvailabilityCheckerResolverFactory

    typealias Factory =
        AppStateManagerFactory &
        SiriHelperFactory &
        NetShieldPropertyProviderFactory &
        NATTypePropertyProviderFactory &
        SafeModePropertyProviderFactory &
        PropertiesManagerFactory &
        AvailabilityCheckerResolverFactory &
        ServerStorageFactory &
        ServerTierCheckerFactory

    init(_ factory: Factory) {
        self.appStateManager = factory.makeAppStateManager()
        self.serverStorage = factory.makeServerStorage()
        self.propertiesManager = factory.makePropertiesManager()
        self.serverTierChecker = factory.makeServerTierChecker()
        self.availabilityCheckerResolverFactory = factory
        self.netShieldPropertyProvider = factory.makeNetShieldPropertyProvider()
        self.natTypePropertyProvider = factory.makeNATTypePropertyProvider()
        self.safeModePropertyProvider = factory.makeSafeModePropertyProvider()
    }
    
    public func connect(withIntent intent: ConnectionSpec) async throws {
        let openVpnConfig = self.propertiesManager.openVpnConfig
        let wireguardConfig = self.propertiesManager.wireguardConfig
        let availabilityCheckerResolver = availabilityCheckerResolverFactory.makeAvailabilityCheckerResolver(
            openVpnConfig: openVpnConfig,
            wireguardConfig: wireguardConfig
        )
        var smartProtocolConfig = propertiesManager.smartProtocolConfig
        if !propertiesManager.featureFlags.wireGuardTls {
            // Don't try to connect using TCP or TLS if WireGuardTls feature flag is turned off
            smartProtocolConfig = smartProtocolConfig
                .configWithWireGuard(tcpEnabled: false, tlsEnabled: false)
        }
        let connectionPreparer = VpnConnectionPreparer(
            appStateManager: self.appStateManager,
            serverTierChecker: self.serverTierChecker,
            availabilityCheckerResolver: availabilityCheckerResolver,
            smartProtocolConfig: smartProtocolConfig,
            openVpnConfig: openVpnConfig,
            wireguardConfig: wireguardConfig)
        let connectionProtocol: ConnectionProtocol = propertiesManager.smartProtocol
        ? .smartProtocol
        : .vpnProtocol(propertiesManager.vpnProtocol)

        let server = try selectServer(intent: intent, connectionProtocol: connectionProtocol)

        DispatchQueue.main.async {
            self.appStateManager.prepareToConnect()
            connectionPreparer.determineServerParametersAndConnect(
                requestId: UUID(),
                with: connectionProtocol,
                to: server,
                netShieldType: self.netShieldType,
                natType: self.natType,
                safeMode: self.safeMode,
                intent: intent.connectionRequestType
            )
        }
    }

    public func disconnect() async throws {
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) -> Void in
            appStateManager.disconnect {
                continuation.resume()
            }
        }
    }

    // MARK: - Connection settings from other providers

    private let netShieldPropertyProvider: NetShieldPropertyProvider
    private var netShieldType: NetShieldType {
        return netShieldPropertyProvider.netShieldType
    }

    private let natTypePropertyProvider: NATTypePropertyProvider
    private var natType: NATType {
        return natTypePropertyProvider.natType
    }

    private let safeModePropertyProvider: SafeModePropertyProvider
    private var safeMode: Bool? {
        return safeModePropertyProvider.safeMode
    }

    // MARK: - Server select

    // todo: Whole server selection should probably be refactored, because now `ConnectionSpec` is not
    // exactly the same as old `ConnectionRequest`
    private func selectServer(intent: ConnectionSpec, connectionProtocol: ConnectionProtocol) throws -> ServerModel {

        @Dependency(\.getCurrentUserTier) var getCurrentUserTier
        let currentUserTier = (try? getCurrentUserTier()) ?? .freeTier

        let type = intent.serverType

        let serverManager: ServerManager = ServerManagerImplementation.instance(
            forTier: currentUserTier,
            serverStorage: serverStorage
        )

        // todo: when old code is deleted, refactor server selector to throw directly
        var notifyResolutionUnavailableCalled: (forSpecificCountry: Bool, type: ServerType, reason: ResolutionUnavailableReason)?

        let selector = VpnServerSelector(serverType: type,
                                         userTier: currentUserTier,
                                         connectionProtocol: connectionProtocol,
                                         smartProtocolConfig: propertiesManager.smartProtocolConfig,
                                         appStateGetter: { [unowned self] in
            self.appStateManager.state
        })
        selector.changeActiveServerType = { _ in }
        selector.notifyResolutionUnavailable = { forSpecificCountry, type, reason in
            notifyResolutionUnavailableCalled = (forSpecificCountry, type, reason)
        }

        let selected = selector.selectServer(connectionRequest: intent.connectionRequest)

        // todo: when old code is deleted, refactor server selector to throw directly
        if let notifyResolutionUnavailableCalled {
            throw GatewayError.resolutionUnavailable(
                forSpecificCountry: notifyResolutionUnavailableCalled.forSpecificCountry,
                type: notifyResolutionUnavailableCalled.type,
                reason: notifyResolutionUnavailableCalled.reason
            )
        }

        guard let selected else {
            throw GatewayError.noServerFound
        }

        log.debug("Server selected: \(selected.logDescription)", category: .connectionConnect)
        return selected
    }

    // MARK: - Subtypes

    enum GatewayError: Error {
        case noServerFound
        case resolutionUnavailable(forSpecificCountry: Bool, type: ServerType, reason: ResolutionUnavailableReason)
    }
}

extension ConnectionSpec {
    var serverType: ServerType {
        switch location {
        case .secureCore:
            return .secureCore
        default:
            if features.contains(.p2p) {
                return .p2p
            }
            if features.contains(.tor) {
                return .tor
            }

            return .standard
        }
    }
}

fileprivate extension ConnectionSpec {

    // Important! Use only for server selection. Only serverType and connectionType are filled in correctly.
    // If used elsewhere, please fill in other properties properly.
    var connectionRequest: ConnectionRequest {
        ConnectionRequest(
            serverType: self.serverType,
            connectionType: self.connectionRequestType,
            connectionProtocol: .smartProtocol, // This is NOT used in server selection
            netShieldType: .off,
            natType: .default,
            safeMode: nil,
            profileId: nil,
            trigger: nil
        )
    }

    var connectionRequestType: ConnectionRequestType {
        switch self.location {
        case .fastest:
            return .fastest

        case .region(let code):
            return .country(code, .fastest)

        case .exact:
            return .random // todo:

        case .secureCore(let secureCoreSpecs):
            switch secureCoreSpecs {
            case .fastest:
                return .fastest
            case .fastestHop(to: let to):
                return .country(to, .fastest)
            case .hop(to: let to, _):
                return .country(to, .fastest) // todo:
            }
        }
    }

}
