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

@testable import Persistence

final class ServerSelectionTests: IsolatedResourceDrivenDatabaseTestCase {

    override class var resourceName: String { "TestServers" }

    // MARK: Filtering & Ordering

    func testFastestFreeServer() throws {
        let result = try sut.getFirstServer(
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
        let result = try sut.getFirstServer(
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
        let result = try sut.getFirstServer(
            filteredBy: [.features(.standard(with: .tor))],
            orderedBy: .fastest
        )

        let endpoint = try XCTUnwrap(result)
        XCTAssertTrue(endpoint.logical.feature.contains(.tor))
        XCTAssertTrue(endpoint.logical.feature.isDisjoint(with: .secureCore))
    }

    func testRandomServer() throws {
        let result = try sut.getFirstServer(filteredBy: [], orderedBy: .random)

        // We can't make many solid assertions about the resulting server since it will be chosen at random
        XCTAssertNotNil(result)
    }

    func testFastestSpecifiedCountryAndFeatureServer() throws {
        let result = try sut.getFirstServer(
            filteredBy: [
                .kind(.standard(country: "US")),
                .features(.standard(with: .tor))
            ],
            orderedBy: .fastest
        )

        let server = try XCTUnwrap(result)

        XCTAssertEqual(server.logical.id, "featureRichUSServer")
    }

    func testFastestSpecifiedCityServer() throws {
        let result = try sut.getFirstServer(
            filteredBy: [.city("Vancouver")],
            orderedBy: .fastest
        )

        let server = try XCTUnwrap(result)

        XCTAssertEqual(server.logical.id, "fastestVancouverServer")
    }

    func testFastestSpecifiedGatewayServer() throws {
        let result = try sut.getFirstServer(
            filteredBy: [.kind(.gateway(name: "Mega Gateway 2000"))],
            orderedBy: .fastest
        )

        let server = try XCTUnwrap(result)

        XCTAssertEqual(server.logical.id, "fastestMegaGateway2000Server")
    }

    func testFreeTorServers() throws {
        let results = try sut.getServers(
            filteredBy: [
                .features(.standard(with: .tor)),
                .tier(.max(tier: 0))
            ],
            orderedBy: .nameAscending
        )

        XCTAssertEqual(results.count, 0)
    }

    func testSpecifiedCountrySecureCoreServers() throws {
        let results = try sut.getServers(
            filteredBy: [
                .kind(.standard(country: "US")),
                .features(.secureCore)
            ],
            orderedBy: .nameAscending
        )

        XCTAssertEqual(results.count, 0)
    }

    // Ordering servers by name requires additional comparison
    func testServerNameOrdering() throws {
        let results = try sut.getServers(
            filteredBy: [.kind(.standard(country: "DE"))],
            orderedBy: .nameAscending
        )

        let serverNames = results.map { $0.logical.name }

        // Naive string comparison would result in DE#10 < DE#9
        XCTAssertEqual(serverNames, ["DE#9", "DE#10"])
    }
}
