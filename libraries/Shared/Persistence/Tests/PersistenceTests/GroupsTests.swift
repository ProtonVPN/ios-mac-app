//
//  Created on 10/01/2024.
//
//  Copyright (c) 2024 Proton AG
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

final class ServersTests: XCTestCase {

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

    func testStandardGroups() throws {
        let groups = try sut.groups([.features(.standard)])

        XCTAssertEqual(groups.count, 8)

        assert(
            groups[0],
            isOfKind: .gateway(name: "Mega Gateway 2000"),
            hasServerCount: 2,
            isUnderMaintenance: false,
            supports: .all
        )

        assert(
            groups[2],
            isOfKind: .country(code: "DE"),
            hasServerCount: 2,
            isUnderMaintenance: false,
            supports: [.ikev2, .wireGuardTLS]
        )

        assert(
            groups[6],
            isOfKind: .country(code: "AE"), // Verify groups are ordered by localized country name and not code
            hasServerCount: 1,
            isUnderMaintenance: false,
            supports: [.all]
        )

    }

    func testSecureCoreGroups() throws {
        let groups = try sut.groups([.features(.secureCore)])

        XCTAssertEqual(groups.count, 1)

        assert(
            groups[0],
            isOfKind: .country(code: "CA"),
            hasServerCount: 1,
            isUnderMaintenance: false,
            supports: [.all]
        )
    }

    func assert(
        _ group: ServerGroupInfo,
        isOfKind kind: ServerGroupInfo.Kind,
        hasServerCount count: Int,
        isUnderMaintenance: Bool, 
        supports protocolSet: ProtocolSupport
    ) {
        XCTAssertEqual(group.kind, kind)
        XCTAssertEqual(group.serverCount, count)
        XCTAssertEqual(group.isUnderMaintenance, isUnderMaintenance)
        XCTAssertEqual(group.protocolSupport, protocolSet)
    }
}
