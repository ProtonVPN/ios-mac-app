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

final class ServerSelectionTests: XCTestCase {

    class func loadTestServers() throws -> [VPNServer] {
        let jsonPath = try XCTUnwrap(Bundle.module.path(forResource: "TestServers", ofType: "json"))
        let jsonURL = URL(fileURLWithPath: jsonPath)
        let data = try Data(contentsOf: jsonURL)
        return try JSONDecoder().decode([VPNServer].self, from: data)
    }

    static var repository: ServerRepository!

    // Define a static repository and initialise it once since we don't modify it during tests
    override class func setUp() {
        let servers = try! loadTestServers()
        repository = .liveValue
        try! repository.insertServers(servers)
    }

    var sut: ServerRepository {
        Self.repository
    }

    // MARK: Filtering & Ordering

    func testFastestFreeServer() throws {
        let result = try sut.server([
            .features(.standard),
            .maximumTier(0)
        ], .fastest)

        let server = try XCTUnwrap(result)
        XCTAssertEqual(server.logical.id, "fastestFreeServer")
        XCTAssertTrue(server.logical.feature.isDisjoint(with: .secureCore))
    }

    /// The fastest server in our list has overrides indicating that WireGuard UDP is not supported
    func testFastestFreeServerForWireGuardUDP() throws {
        let result = try sut.server([
            .features(.standard),
            .supports(protocol: [.wireGuardUDP]),
            .maximumTier(0)
        ], .fastest)

        let endpoint = try XCTUnwrap(result)
        XCTAssertEqual(endpoint.logical.id, "fastestFreeWireGuardUDPServer")
        XCTAssertTrue(endpoint.logical.feature.isDisjoint(with: .secureCore))
    }

    func testFastestTorServer() throws {
        let result = try! sut.server([
            .features(.standard(with: .tor))
        ], .fastest)

        let endpoint = try! XCTUnwrap(result)
        XCTAssertTrue(endpoint.logical.feature.contains(.tor))
        XCTAssertTrue(endpoint.logical.feature.isDisjoint(with: .secureCore))
    }

    func testRandomServer() throws {
        let result = try sut.server([], .random)

        // We can't make many solid assertions about the resulting server since it will be chosen at random
        XCTAssertNotNil(result)
    }

    func testFastestSpecifiedCountryAndFeatureServer() throws {
        let result = try sut.server([
            .kind(.standard(country: "US")),
            .features(.standard(with: .tor))
        ], .fastest)

        let server = try XCTUnwrap(result)

        XCTAssertEqual(server.logical.id, "featureRichUSServer")
    }

    func testFastestSpecifiedCityServer() throws {
        let result = try sut.server([.city("Vancouver")], .fastest)

        let server = try XCTUnwrap(result)

        XCTAssertEqual(server.logical.id, "fastestVancouverServer")
    }

    func testFastestSpecifiedGatewayServer() throws {
        let result = try sut.server([.kind(.gateway(name: "Mega Gateway 2000"))], .fastest)

        let server = try XCTUnwrap(result)

        XCTAssertEqual(server.logical.id, "fastestMegaGateway2000Server")
    }

    func testFreeTorServers() throws {
        let results = try sut.servers([
            .features(.standard(with: .tor)),
            .maximumTier(0)
        ], .nameAscending)

        XCTAssertEqual(results.count, 0)
    }

    func testSpecifiedCountrySecureCoreServers() throws {
        let results = try sut.servers([
            .kind(.standard(country: "US")),
            .features(.secureCore)
        ], .nameAscending)

        XCTAssertEqual(results.count, 0)
    }

    // Ordering servers by name requires additional comparison
    func testServerNameOrdering() throws {
        let results = try sut.servers([
            .kind(.standard(country: "DE"))
        ], .nameAscending)

        XCTAssertEqual(results.count, 2)

        // Naive string comparison would result in DE#10 < DE#9
        XCTAssertEqual(results[0].logical.name, "DE#9")
        XCTAssertEqual(results[1].logical.name, "DE#10")
    }
}
