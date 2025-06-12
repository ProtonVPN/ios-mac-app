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
import Persistence
import VPNAppCore
import VPNShared

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
    private let propertiesManager: PropertiesManagerProtocol
    private let serverTierChecker: ServerTierChecker
    private let availabilityCheckerResolverFactory: AvailabilityCheckerResolverFactory

    typealias Factory =
        AppStateManagerFactory &
        AvailabilityCheckerResolverFactory &
        NATTypePropertyProviderFactory &
        NetShieldPropertyProviderFactory &
        PropertiesManagerFactory &
        SafeModePropertyProviderFactory &
        ServerTierCheckerFactory &
        SiriHelperFactory

    init(_ factory: Factory) {
        appStateManager = factory.makeAppStateManager()
        propertiesManager = factory.makePropertiesManager()
        serverTierChecker = factory.makeServerTierChecker()
        availabilityCheckerResolverFactory = factory
        netShieldPropertyProvider = factory.makeNetShieldPropertyProvider()
        natTypePropertyProvider = factory.makeNATTypePropertyProvider()
        safeModePropertyProvider = factory.makeSafeModePropertyProvider()
    }

    public func connect(withIntent intent: ConnectionSpec) async throws {
        let wireguardConfig = propertiesManager.wireguardConfig
        let availabilityCheckerResolver = availabilityCheckerResolverFactory.makeAvailabilityCheckerResolver(
            wireguardConfig: wireguardConfig
        )
        var smartProtocolConfig = propertiesManager.smartProtocolConfig
        if !propertiesManager.featureFlags.wireGuardTls {
            // Don't try to connect using TCP or TLS if WireGuardTls feature flag is turned off
            smartProtocolConfig = smartProtocolConfig
                .configWithWireGuard(tcpEnabled: false, tlsEnabled: false)
        }
        let connectionPreparer = VpnConnectionPreparer(
            appStateManager: appStateManager,
            serverTierChecker: serverTierChecker,
            availabilityCheckerResolver: availabilityCheckerResolver,
            smartProtocolConfig: smartProtocolConfig,
            wireguardConfig: wireguardConfig)
        let connectionProtocol: ConnectionProtocol = propertiesManager.smartProtocol
            ? .smartProtocol
            : .vpnProtocol(propertiesManager.vpnProtocol)

        let server = try selectServer(intent: intent, connectionProtocol: connectionProtocol)

        propertiesManager.lastPreparedServer = server

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
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            appStateManager.disconnect {
                continuation.resume()
            }
        }
    }

    // MARK: - Connection settings from other providers

    private let netShieldPropertyProvider: NetShieldPropertyProvider
    private var netShieldType: NetShieldType {
        netShieldPropertyProvider.netShieldType
    }

    private let natTypePropertyProvider: NATTypePropertyProvider
    private var natType: NATType {
        natTypePropertyProvider.natType
    }

    private let safeModePropertyProvider: SafeModePropertyProvider
    private var safeMode: Bool? {
        safeModePropertyProvider.safeMode
    }

    // MARK: - Server select

    // TODO: Whole server selection should probably be refactored, because now `ConnectionSpec` is not
    // exactly the same as old `ConnectionRequest`
    private func selectServer(intent: ConnectionSpec, connectionProtocol: ConnectionProtocol) throws -> ServerModel {
        @Dependency(\.getCurrentUserTier) var getCurrentUserTier
        let currentUserTier = (try? getCurrentUserTier()) ?? .freeTier

        let type = intent.serverType

        // TODO: when old code is deleted, refactor server selector to throw directly
        var notifyResolutionUnavailableCalled: (forSpecificCountry: Bool, type: ServerType, reason: ResolutionUnavailableReason)?

        let selector = VpnServerSelector(serverType: type,
                                         userTier: currentUserTier,
                                         connectionProtocol: connectionProtocol,
                                         smartProtocolConfig: propertiesManager.smartProtocolConfig,
                                         appStateGetter: { [unowned self] in
                                             appStateManager.state
                                         })
        selector.changeActiveServerType = { _ in }
        selector.notifyResolutionUnavailable = { forSpecificCountry, type, reason in
            notifyResolutionUnavailableCalled = (forSpecificCountry, type, reason)
        }

        let selected = selector.selectServer(connectionRequest: intent.connectionRequest)

        // TODO: when old code is deleted, refactor server selector to throw directly
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

private extension ConnectionSpec {
    // Important! Use only for server selection. Only serverType and connectionType are filled in correctly.
    // If used elsewhere, please fill in other properties properly.
    var connectionRequest: ConnectionRequest {
        ConnectionRequest(
            serverType: serverType,
            connectionType: connectionRequestType,
            connectionProtocol: .smartProtocol, // This is NOT used in server selection
            netShieldType: .off,
            natType: .default,
            safeMode: nil,
            profileId: nil,
            profileName: nil,
            trigger: nil
        )
    }

    var connectionRequestType: ConnectionRequestType {
        switch location {
        case .fastest:
            return .fastest

        case .random:
            return .random

        case let .region(code):
            return .country(code, .fastest)

        case let .gateway(name):
            return .gateway(name: name)

        case let .exact(_, _, number, subregion, regionCode):
            if let number {
                @Dependency(\.serverRepository) var serverRepository
                let name = "\(regionCode)#\(number)"
                let filters: [VPNServerFilter?] = [.name(name), subregion.map { .city($0) }]
                if let server = serverRepository.getFirstServer(filteredBy: filters.compactMap { $0 }, orderedBy: .none) {
                    return .country(regionCode, .server(.init(server: server)))
                }
                log.warning("Failed to find server matching \(filters), falling back to fastest in \(regionCode)")
                return .country(regionCode, .fastest)
            } else if let subregion {
                return .city(country: regionCode, city: subregion)
            } else {
                return .country(regionCode, .fastest)
            }

        case let .secureCore(secureCoreSpecs):
            switch secureCoreSpecs {
            case .fastest:
                return .fastest
            case .random:
                return .random
            case let .fastestHop(to: to):
                return .country(to, .fastest)
            case let .hop(to, via):
                @Dependency(\.serverRepository) var serverRepository
                if let server = serverRepository.getFirstServer(filteredBy: [.entryCountryCode(via), .exitCountryCode(to)], orderedBy: .none) {
                    return .country(to, .server(.init(server: server)))
                }
                return .country(to, .fastest)
            }
        }
    }
}
