//
//  Created on 29/01/2024.
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

import Foundation
import XCTest

import Domain
import Persistence

final class LoadsTests: TestIsolatedDatabaseTestCase {

    func testLoadsUpdated() throws {
        try sut.upsert(servers: [
            mockServer(withID: "a", load: 50, score: 2, status: 1),
            mockServer(withID: "b", load: 25, score: 1, status: 0)
        ])

        let serverA = try sut.getFirstServer(filteredBy: [.logicalID("a")], orderedBy: .none)
        let serverB = try sut.getFirstServer(filteredBy: [.logicalID("b")], orderedBy: .none)

        XCTAssertEqual(serverA?.logical.load, 50)
        XCTAssertEqual(serverA?.logical.score, 2)
        XCTAssertEqual(serverA?.logical.status, 1)

        XCTAssertEqual(serverB?.logical.load, 25)
        XCTAssertEqual(serverB?.logical.score, 1)
        XCTAssertEqual(serverB?.logical.status, 0)

        // Now perform update

        try sut.upsert(loads: [
            .init(serverId: "a", load: 75, score: 3, status: 1),
            .init(serverId: "b", load: 0, score: 0, status: 1)
        ])

        let updatedServerA = try sut.getFirstServer(filteredBy: [.logicalID("a")], orderedBy: .none)
        let updatedServerB = try sut.getFirstServer(filteredBy: [.logicalID("b")], orderedBy: .none)

        XCTAssertEqual(updatedServerA?.logical.load, 75)
        XCTAssertEqual(updatedServerA?.logical.score, 3)
        XCTAssertEqual(updatedServerA?.logical.status, 1)

        XCTAssertEqual(updatedServerB?.logical.load, 0)
        XCTAssertEqual(updatedServerB?.logical.score, 0)
        XCTAssertEqual(updatedServerB?.logical.status, 1)
    }

}
