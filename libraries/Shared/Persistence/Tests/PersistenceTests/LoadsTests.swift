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
@testable import Persistence
import PersistenceTestSupport

final class LoadsTests: TestIsolatedDatabaseTestCase {
    func testLoadsUpdated() throws {
        repository.upsert(servers: [
            TestData.createMockServer(withID: "a", load: 50, score: 2, status: 1),
            TestData.createMockServer(withID: "b", load: 25, score: 1, status: 1),
        ])

        let serverA = repository.getFirstServer(filteredBy: [.logicalID("a")], orderedBy: .none)
        let serverB = repository.getFirstServer(filteredBy: [.logicalID("b")], orderedBy: .none)

        XCTAssertEqual(serverA?.logical.load, 50)
        XCTAssertEqual(serverA?.logical.score, 2)
        XCTAssertEqual(serverA?.logical.status, 1)

        XCTAssertEqual(serverB?.logical.load, 25)
        XCTAssertEqual(serverB?.logical.score, 1)
        XCTAssertEqual(serverB?.logical.status, 1)

        // Now perform update

        repository.upsert(loads: [
            .init(serverId: "a", load: 75, score: 3, status: 1),
            .init(serverId: "b", load: 0, score: 0, status: 0),
        ])

        let updatedServerA = repository.getFirstServer(filteredBy: [.logicalID("a")], orderedBy: .none)
        let updatedServerB = repository.getFirstServer(filteredBy: [.logicalID("b")], orderedBy: .none)

        XCTAssertEqual(updatedServerA?.logical.load, 75)
        XCTAssertEqual(updatedServerA?.logical.score, 3)
        XCTAssertEqual(updatedServerA?.logical.status, 1)

        XCTAssertEqual(updatedServerB?.logical.load, 0)
        XCTAssertEqual(updatedServerB?.logical.score, 0)
        XCTAssertEqual(updatedServerB?.logical.status, 0)
    }

    /// When according to the server loads response, a server comes online from maintenance, we don't know which
    /// endpoint has just come back online. In this case, we don't have enough information to set the logical status
    /// to 0.
    func testLoadsIgnoredForLogicalsComingOutOfMaintenance() throws {
        let serverUnderMaintenance = TestData.serverUnderMaintenance(
            id: "a",
            name: "CH#1",
            countryCode: "CH",
            tier: 3,
            load: 25,
            score: 2
        )
        let activeServer = TestData.createMockServer(
            withID: "b",
            name: "CH#2",
            countryCode: "CH",
            tier: 3,
            load: 30,
            score: 3,
            status: 1
        )

        repository.upsert(servers: [serverUnderMaintenance, activeServer])

        let newLoad = 10
        let newScore: Double = 0

        repository.upsert(loads: [
            // Server `a` leaves maintenance, so this update should be disregarded
            .init(serverId: "a", load: newLoad, score: newScore, status: 1),
            // Server `b` is wasn't under maintenance, so we can safely update these values locally
            .init(serverId: "b", load: newLoad, score: newScore, status: 1),
        ])

        let updatedServerA = repository.getFirstServer(filteredBy: [.logicalID("a")], orderedBy: .none)
        let updatedServerB = repository.getFirstServer(filteredBy: [.logicalID("b")], orderedBy: .none)

        // This logical should still be marked as under maintenance, despite the new status being 0, since we don't
        // know which of its endpoints to update.
        XCTAssertEqual(updatedServerA, serverUnderMaintenance)
        XCTAssertEqual(updatedServerA?.logical.isUnderMaintenance, true)

        // This logical should also still be marked as under maintenance, but we should respect the other values
        // (score, load) from the API response
        XCTAssertEqual(updatedServerB?.logical.load, newLoad)
        XCTAssertEqual(updatedServerB?.logical.score, newScore)
        XCTAssertEqual(updatedServerB?.logical.isUnderMaintenance, false)
    }
}
