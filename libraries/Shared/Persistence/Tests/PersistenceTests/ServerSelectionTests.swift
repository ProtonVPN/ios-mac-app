//
//  Created on 01/12/2023.
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

import XCTest

import Dependencies
import GRDB

import Domain
import PersistenceTestSupport
@testable import Persistence

final class ServerSelectionTests: CaseIsolatedDatabaseTestCase {

    override class func setUp() {
        super.setUp()
        let servers = try! fetch([VPNServer].self, fromResourceNamed: "TestServers")
        internalRepository!.upsert(servers: servers)
    }

    // MARK: Filtering & Ordering

    func testFastestOverallServer() throws {
        let result = repository.getFirstServer(filteredBy: [], orderedBy: .fastest)

        let server = try XCTUnwrap(result)
        XCTAssertEqual(server.logical.id, "fastestFeaturelessUSServer")
        XCTAssertTrue(server.logical.feature.isDisjoint(with: .secureCore))
    }

    func testFastestFreeServer() throws {
        let result = repository.getFirstServer(
            filteredBy: [
                .features(.standard),
                .tier(.max(tier: 0))
            ],
            orderedBy: .fastest
        )

        let server = try XCTUnwrap(result)
        XCTAssertEqual(server.logical.id, "fastestFreeServer")
        XCTAssertTrue(server.logical.feature.isDisjoint(with: .secureCore))
    }

    /// The fastest server in our list has overrides indicating that WireGuard UDP is not supported
    func testFastestFreeServerForWireGuardUDP() throws {
        let result = repository.getFirstServer(
            filteredBy: [
                .features(.standard),
                .supports(protocol: [.wireGuardUDP]),
                .tier(.max(tier: 0))
            ],
            orderedBy: .fastest
        )

        let endpoint = try XCTUnwrap(result)
        XCTAssertEqual(endpoint.logical.id, "fastestFreeWireGuardUDPServer")
        XCTAssertTrue(endpoint.logical.feature.isDisjoint(with: .secureCore))
    }

    func testFastestTorServer() throws {
        let result = repository.getFirstServer(
            filteredBy: [.features(.standard(with: .tor))],
            orderedBy: .fastest
        )

        let endpoint = try XCTUnwrap(result)
        XCTAssertTrue(endpoint.logical.feature.contains(.tor))
        XCTAssertTrue(endpoint.logical.feature.isDisjoint(with: .secureCore))
    }

    func testFastestStealthServer() throws {
        let result = repository.getFirstServer(
            filteredBy: [.supports(protocol: .wireGuardTLS)],
            orderedBy: .fastest
        )

        let server = try XCTUnwrap(result)
        XCTAssertEqual(server.logical.id, "DE2")
        XCTAssertTrue(server.supportedProtocols.contains(.wireGuardTLS))
    }

    func testRandomServer() throws {
        let result = repository.getFirstServer(filteredBy: [], orderedBy: .random)

        // We can't make many solid assertions about the resulting server since it will be chosen at random
        XCTAssertNotNil(result)
    }

    func testFastestSpecifiedCountryAndFeatureServer() throws {
        let result = repository.getFirstServer(
            filteredBy: [
                .kind(.country(code: "US")),
                .features(.standard(with: .tor))
            ],
            orderedBy: .fastest
        )

        let server = try XCTUnwrap(result)

        XCTAssertEqual(server.logical.id, "featureRichUSServer")
    }

    func testFastestSpecifiedCityServer() throws {
        let result = repository.getFirstServer(
            filteredBy: [.city("Vancouver")],
            orderedBy: .fastest
        )

        let server = try XCTUnwrap(result)

        XCTAssertEqual(server.logical.id, "fastestVancouverServer")
    }

    func testFastestSpecifiedGatewayServer() throws {
        let result = repository.getFirstServer(
            filteredBy: [.kind(.gateway(name: "Mega Gateway 2000"))],
            orderedBy: .fastest
        )

        let server = try XCTUnwrap(result)

        XCTAssertEqual(server.logical.id, "fastestMegaGateway2000Server")
    }

    func testFreeTorServers() throws {
        let results = repository.getServers(
            filteredBy: [
                .features(.standard(with: .tor)),
                .tier(.max(tier: 0))
            ],
            orderedBy: .nameAscending
        )

        XCTAssertEqual(results.count, 0)
    }

    func testSpecifiedCountrySecureCoreServers() throws {
        let results = repository.getServers(
            filteredBy: [
                .kind(.country(code: "US")),
                .features(.secureCore)
            ],
            orderedBy: .nameAscending
        )

        XCTAssertEqual(results.count, 0)
    }

    /// This test asserts that if the `.supports(protocol)` filter is used, only servers that support at least one of
    /// the specified protocols are returned.
    ///
    /// Note the protocols used here are selected at random and do not represent the set of protocols that are currently
    /// supported by the app targets.
    func testReturnsServersAccordingToSpecifiedProtocols() throws {
        let ikeResults = repository.getServers(
            filteredBy: [.kind(.country(code: "DE")), .supports(protocol: .ikev2)],
            orderedBy: .nameAscending
        )

        let ikeServerIDs = ikeResults.map { $0.logical.id }

        XCTAssertTrue(ikeResults.allSatisfy { $0.protocolSupport.contains(.ikev2) })
        XCTAssertEqual(ikeServerIDs, ["DE1"])

        let stealthResults = repository.getServers(
            filteredBy: [.kind(.country(code: "DE")), .supports(protocol: .wireGuardTLS)],
            orderedBy: .nameAscending
        )

        let stealthServerIDs = stealthResults.map { $0.logical.id }

        XCTAssertTrue(stealthResults.allSatisfy { $0.protocolSupport.contains(.wireGuardTLS) })
        XCTAssertEqual(stealthServerIDs, ["DE2"])

        let ikeOrStealthResults = repository.getServers(
            filteredBy: [.kind(.country(code: "DE")), .supports(protocol: [.ikev2, .wireGuardTLS])],
            orderedBy: .nameAscending
        )

        let ikeOrStealthIDs = Set(ikeOrStealthResults.map { $0.logical.id })

        XCTAssertTrue(ikeOrStealthResults.allSatisfy { !$0.protocolSupport.isDisjoint(with: [.ikev2, .wireGuardTLS]) })
        XCTAssertEqual(ikeOrStealthIDs, Set(arrayLiteral: "DE1", "DE2"))
    }

    // Ordering servers by name requires additional comparison
    func testServerNameOrdering() throws {
        let results = repository.getServers(
            filteredBy: [.kind(.country(code: "DE"))],
            orderedBy: .nameAscending
        )

        let serverNames = results.map { $0.logical.name }

        // Naive string comparison would result in DE#10 < DE#9
        XCTAssertEqual(serverNames, ["DE#9", "DE#10"])
    }
}
