//
//  VpnServerSelectorTests.swift
//  vpncore - Created on 2020-06-02.
//
//  Copyright (c) 2019 Proton Technologies AG
//
//  This file is part of LegacyCommon.
//
//  vpncore is free software: you can redistribute it and/or modify
//  it under the terms of the GNU General Public License as published by
//  the Free Software Foundation, either version 3 of the License, or
//  (at your option) any later version.
//
//  vpncore is distributed in the hope that it will be useful,
//  but WITHOUT ANY WARRANTY; without even the implied warranty of
//  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
//  GNU General Public License for more details.
//
//  You should have received a copy of the GNU General Public License
//  along with LegacyCommon.  If not, see <https://www.gnu.org/licenses/>.
//

import XCTest

import Dependencies

import Domain
import VPNAppCore

import Persistence

@testable import LegacyCommon

class VpnServerSelectorTests: XCTestCase {
    let connectionProtocol: ConnectionProtocol = .vpnProtocol(.ike)
    let smartProtocolConfig = MockTestData().defaultClientConfig.smartProtocolConfig
    let appStateGetter: (() -> AppState) = { return .disconnected }

    static var repository: ServerRepository!
    static var mockServers: [String: VPNServer]!

    var repository: ServerRepository { Self.repository }
    var servers: [String: VPNServer] { Self.mockServers }

    override class func setUp() {
        super.setUp()
        let mockServers = [
            makeMockServer(id: "GBX", countryCode: "GB", gatewayName: "X", tier: 3, score: 1, feature: .restricted),
            makeMockServer(id: "GB0", countryCode: "GB", tier: 3, score: 1),
            makeMockServer(id: "GB1", countryCode: "GB", tier: 2, score: 3, feature: .tor),
            makeMockServer(id: "GB2", countryCode: "GB", tier: 1, score: 5, feature: .secureCore),
            makeMockServer(id: "DE0", countryCode: "DE", tier: 3, score: 2),
            makeMockServer(id: "DE1", countryCode: "DE", tier: 2, score: 4, feature: .tor),
            makeMockServer(id: "DE2", countryCode: "DE", tier: 1, score: 6, feature: .secureCore),
            makeMockServer(id: "US0", countryCode: "US", tier: 1, score: 7),
            makeMockServer(id: "US1", countryCode: "US", tier: 2, score: 6),
            makeMockServer(id: "CH0", countryCode: "CH", tier: 2, score: 1.5, status: 0),
            makeMockServer(id: "CH1", countryCode: "CH", tier: 2, score: 2, status: 0),
            makeMockServer(id: "PL0", countryCode: "PL", tier: 1, score: 7, protocols: .ikev2),
            makeMockServer(id: "PL1", countryCode: "PL", tier: 2, score: 6, protocols: [.wireGuardTLS, .openVPNUDP])
        ]

        Self.mockServers = mockServers.reduce(into: [:]) { $0[$1.logical.id] = $1 }

        Self.repository = withDependencies {
            $0.databaseConfiguration = .withTestExecutor(databaseType: .ephemeral)
        } operation: {
            ServerRepository.liveValue
        }

        repository.upsert(servers: mockServers)
    }

    func testServersUnchangedByRoundTrip() throws {
        servers.values.forEach { server in
            let serverFromDB = repository.getFirstServer(filteredBy: [.logicalID(server.logical.id)], orderedBy: .none)
            XCTAssertEqual(serverFromDB, server)
        }
    }

    func selectServer(
        connectionRequest: ConnectionRequest,
        serverType: ServerType,
        userTier: Int,
        connectionProtocol: ConnectionProtocol,
        smartProtocolConfig: SmartProtocolConfig,
        appStateGetter: @escaping () -> AppState,
        changeActiveServerType: @escaping (ServerType) -> Void = { _ in },
        notifyResolutionUnavailable: @escaping (Bool, ServerType, ResolutionUnavailableReason) -> Void = { _, _, _  in }
    ) -> ServerModel? {
        return withDependencies {
            $0.serverRepository = repository
        } operation: {
            let selector = VpnServerSelector(
                serverType: serverType,
                userTier: userTier,
                connectionProtocol: connectionProtocol,
                smartProtocolConfig: smartProtocolConfig,
                appStateGetter: appStateGetter
            )
            selector.changeActiveServerType = changeActiveServerType
            selector.notifyResolutionUnavailable = notifyResolutionUnavailable
            return selector.selectServer(connectionRequest: connectionRequest)
        }
    }

    func testSelectsFastestOverall() throws {
        let currentUserTier = 3
        let type = ServerType.unspecified
        let connectionRequest = ConnectionRequest(serverType: .unspecified, connectionType: .fastest, connectionProtocol: connectionProtocol, netShieldType: .off, natType: .default, safeMode: true, profileId: nil, trigger: nil)

        let server = selectServer(
            connectionRequest: connectionRequest,
            serverType: type,
            userTier: currentUserTier,
            connectionProtocol: connectionProtocol,
            smartProtocolConfig: smartProtocolConfig,
            appStateGetter: appStateGetter
        )

        XCTAssertEqual(server?.id, "GB0")
    }

    func testSelectsFastestInCountry() throws {
        let currentUserTier = 3
        let type = ServerType.unspecified
        let connectionRequest = ConnectionRequest(serverType: .unspecified, connectionType: .country("DE", .fastest), connectionProtocol: connectionProtocol, netShieldType: .off, natType: .default, safeMode: true, profileId: nil, trigger: nil)

        let server = selectServer(
            connectionRequest: connectionRequest,
            serverType: type,
            userTier: currentUserTier,
            connectionProtocol: connectionProtocol,
            smartProtocolConfig: smartProtocolConfig,
            appStateGetter: appStateGetter
        )

        XCTAssertEqual(server?.id, "DE0")
    }

    func testSelectsFastestInAvailableTier() throws {
        let currentUserTier = 1
        let type = ServerType.unspecified
        let connectionRequest = ConnectionRequest(serverType: .unspecified, connectionType: .fastest, connectionProtocol: connectionProtocol, netShieldType: .off, natType: .default, safeMode: true, profileId: nil, trigger: nil)

        let server = selectServer(
            connectionRequest: connectionRequest,
            serverType: type,
            userTier: currentUserTier,
            connectionProtocol: connectionProtocol,
            smartProtocolConfig: smartProtocolConfig,
            appStateGetter: appStateGetter
        )

        XCTAssertEqual(server?.id, "GB2")
    }

    func testSelectsFastestInAvailableTierByCountry() throws {
        let currentUserTier = 1
        let type = ServerType.unspecified
        let connectionRequest = ConnectionRequest(serverType: .unspecified, connectionType: .country("DE", .fastest), connectionProtocol: connectionProtocol, netShieldType: .off, natType: .default, safeMode: true, profileId: nil, trigger: nil)

        let server = selectServer(
            connectionRequest: connectionRequest,
            serverType: type,
            userTier: currentUserTier,
            connectionProtocol: connectionProtocol,
            smartProtocolConfig: smartProtocolConfig,
            appStateGetter: appStateGetter
        )

        XCTAssertEqual(server?.id, "DE2")
    }

    func testSelectsServer() throws {
        let currentUserTier = 3
        let type = ServerType.unspecified

        let specifiedServer = ServerModel(server: try XCTUnwrap(servers["DE2"]))
        let connectionRequest = ConnectionRequest(serverType: .unspecified, connectionType: .country("DE", .server(specifiedServer)), connectionProtocol: connectionProtocol, netShieldType: .off, natType: .default, safeMode: true, profileId: nil, trigger: nil)

        let server = selectServer(
            connectionRequest: connectionRequest,
            serverType: type,
            userTier: currentUserTier,
            connectionProtocol: connectionProtocol,
            smartProtocolConfig: smartProtocolConfig,
            appStateGetter: appStateGetter
        )

        XCTAssertEqual(server?.id, "DE2")
    }

    func testOnlyReturnsGatewaysWhenGatewayServerExplicitlySpecified() throws {
        let currentUserTier = 3
        let type = ServerType.unspecified

        let fastestConnectionRequest = ConnectionRequest(serverType: .unspecified, connectionType: .country("GB", .fastest), connectionProtocol: connectionProtocol, netShieldType: .off, natType: .default, safeMode: true, profileId: nil, trigger: nil)

        let fastestServer = selectServer(
            connectionRequest: fastestConnectionRequest,
            serverType: type,
            userTier: currentUserTier,
            connectionProtocol: connectionProtocol,
            smartProtocolConfig: smartProtocolConfig,
            appStateGetter: appStateGetter
        )

        // GBX is faster, but it's a gateway so it should be ignored since we're specifying 'fastest' or 'random'
        XCTAssertEqual(fastestServer?.id, "GB0")

        let requestedGatewayServer = try XCTUnwrap(servers["GBX"])
        let gatewayConnectionRequest = ConnectionRequest(
            serverType: .unspecified,
            connectionType: .country("GB", .server(ServerModel(server: requestedGatewayServer))),
            connectionProtocol: connectionProtocol,
            netShieldType: .off,
            natType: .default,
            safeMode: true,
            profileId: nil,
            trigger: nil
        )

        let gatewayServer = selectServer(
            connectionRequest: gatewayConnectionRequest,
            serverType: type,
            userTier: currentUserTier,
            connectionProtocol: connectionProtocol,
            smartProtocolConfig: smartProtocolConfig,
            appStateGetter: appStateGetter
        )

        // We explicitly requested the gateway server, so it should be returned
        XCTAssertEqual(gatewayServer?.id, "GBX")
    }

    func testReturnsNilForEmptyCountry() throws {
        let currentUserTier = 3
        let type = ServerType.unspecified
        let connectionRequest = ConnectionRequest(serverType: .unspecified, connectionType: .country("FR", .random), connectionProtocol: connectionProtocol, netShieldType: .off, natType: .default, safeMode: true, profileId: nil, trigger: nil)

        var notifiedNoResolution = false
        let server = selectServer(
            connectionRequest: connectionRequest,
            serverType: type,
            userTier: currentUserTier,
            connectionProtocol: connectionProtocol,
            smartProtocolConfig: smartProtocolConfig,
            appStateGetter: appStateGetter,
            notifyResolutionUnavailable: { _, _, reason in
                notifiedNoResolution = true
                // We don't have a "location not found" reason
                XCTAssertEqual(reason, ResolutionUnavailableReason.protocolNotSupported)
            }
        )

        XCTAssertNil(server)
        XCTAssertTrue(notifiedNoResolution)
    }

    func testDoesntReturnServerUnderMaintenance() throws {
        let currentUserTier = 3
        let type = ServerType.unspecified
        let connectionRequest = ConnectionRequest(serverType: .unspecified, connectionType: .country("CH", .fastest), connectionProtocol: connectionProtocol, netShieldType: .off, natType: .default, safeMode: true, profileId: nil, trigger: nil)

        var notifiedNoResolution = false
        let server = selectServer(
            connectionRequest: connectionRequest,
            serverType: type,
            userTier: currentUserTier,
            connectionProtocol: connectionProtocol,
            smartProtocolConfig: smartProtocolConfig,
            appStateGetter: appStateGetter,
            notifyResolutionUnavailable: { _, _, reason in
                notifiedNoResolution = true
                XCTAssertEqual(reason, ResolutionUnavailableReason.maintenance)
            }
        )

        XCTAssertNil(server)
        XCTAssertEqual(notifiedNoResolution, true)
    }

    func testDoesntReturnServersOfHigherTiers() throws {
        let currentUserTier = 0
        let type = ServerType.unspecified
        let connectionRequest = ConnectionRequest(serverType: .unspecified, connectionType: .country("US", .random), connectionProtocol: connectionProtocol, netShieldType: .off, natType: .default, safeMode: true, profileId: nil, trigger: nil)

        var notifiedNoResolution = false

        let server = selectServer(
            connectionRequest: connectionRequest,
            serverType: type,
            userTier: currentUserTier,
            connectionProtocol: connectionProtocol,
            smartProtocolConfig: smartProtocolConfig,
            appStateGetter: appStateGetter,
            notifyResolutionUnavailable: { _, _, reason in
                notifiedNoResolution = true
                XCTAssertEqual(reason, ResolutionUnavailableReason.upgrade(1))
            }
        )

        XCTAssertEqual(server, nil)
        XCTAssertEqual(notifiedNoResolution, true)
    }

    func testChangesActiveServerType() throws {
        let currentUserTier = 1
        let type = ServerType.unspecified
        let connectionRequest = ConnectionRequest(serverType: .secureCore, connectionType: .fastest, connectionProtocol: connectionProtocol, netShieldType: .off, natType: .default, safeMode: true, profileId: nil, trigger: nil)

        var currentServerType = ServerType.unspecified

        let server = selectServer(
            connectionRequest: connectionRequest,
            serverType: type,
            userTier: currentUserTier,
            connectionProtocol: connectionProtocol,
            smartProtocolConfig: smartProtocolConfig,
            appStateGetter: appStateGetter,
            changeActiveServerType: { serverType in currentServerType = serverType }
        )

        XCTAssertEqual(server?.id, "GB2")
        XCTAssertEqual(currentServerType, ServerType.secureCore)
    }

    // MARK: - Helpers

    private static func makeMockServer(
        id: String,
        countryCode: String,
        gatewayName: String? = nil,
        tier: Int,
        score: Double,
        feature: ServerFeature = .zero,
        status: Int = 1,
        protocols: ProtocolSupport = .all
    ) -> VPNServer {
        let server = VPNServer(
            logical: Logical(
                id: id,
                name: id,
                domain: id,
                load: 0,
                entryCountryCode: countryCode,
                exitCountryCode: countryCode,
                tier: tier,
                score: score,
                status: status,
                feature: feature,
                city: nil,
                hostCountry: nil,
                translatedCity: nil,
                latitude: 0,
                longitude: 0,
                gatewayName: gatewayName
            ),
            endpoints: [
                ServerEndpoint(
                    id: UUID().uuidString,
                    entryIp: "1.1.1.1",
                    exitIp: "2.2.2.2",
                    domain: id,
                    status: status,
                    label: "1",
                    x25519PublicKey: nil,
                    protocolEntries: mockProtocolEntries(supporting: protocols)
                )
            ]
        )

        XCTAssertEqual(server.supportedProtocols, protocols)
        return server
    }

    private static func mockProtocolEntries(supporting protocols: ProtocolSupport) -> PerProtocolEntries? {
        if protocols == .all {
            return nil
        }

        let entries: [String: ServerProtocolEntry] = VpnProtocol.allCases
            .reduce(into: [:]) {
                if protocols.contains($1.protocolSupport) {
                    $0[$1.apiDescription] = ServerProtocolEntry(ipv4: nil, ports: [25565])
                }
            }

        return PerProtocolEntries(rawValue: entries)
    }
}
