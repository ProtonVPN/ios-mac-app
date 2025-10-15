//
//  Created on 16/10/2025 by Chris Janusiewicz.
//
//  Copyright (c) 2025 Proton AG
//
//  Proton VPN is free software: you can redistribute it and/or modify
//  it under the terms of the GNU General Public License as published by
//  the Free Software Foundation, either version 3 of the License, or
//  (at your option) any later version.
//
//  Proton VPN is distributed in the hope that it will be useful,
//  but WITHOUT ANY WARRANTY; without even the implied warranty of
//  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
//  GNU General Public License for more details.
//
//  You should have received a copy of the GNU General Public License
//  along with Proton VPN.  If not, see <https://www.gnu.org/licenses/>.

import XCTest

import Dependencies
import GRDB

import Domain
@testable import Persistence
import PersistenceTestSupport

final class ServerSelectorTests: TestIsolatedDatabaseTestCase {
    func testSelectsServerWithActiveEndpoints() throws {
        let serverUnderMaintenance = TestData.createMockServer(withID: "a", score: 1, status: 0)

        XCTAssertEqual(serverUnderMaintenance.logical.status, 0)
        XCTAssertTrue(!serverUnderMaintenance.endpoints.isEmpty)
        for endpoint in serverUnderMaintenance.endpoints {
            XCTAssertEqual(endpoint.status, 0)
        }

        let slowActiveServer = TestData.createMockServer(withID: "b", score: 2)

        repository.upsert(servers: [serverUnderMaintenance, slowActiveServer])
        repository.upsert(loads: [.init(serverId: "a", load: 0, score: 1, status: 1)])

        let updatedServer = repository.getFirstServer(filteredBy: [.logicalID("a")], orderedBy: .fastest)!
        XCTAssertEqual(updatedServer.logical.status, 0)
        XCTAssertTrue(!updatedServer.endpoints.isEmpty)
        for endpoint in updatedServer.endpoints {
            XCTAssertEqual(endpoint.status, 0)
        }

        do {
            let selectedServer = try ServerSelector.liveValue.select(.defaultFastest, 2, .all)
            XCTAssertEqual(selectedServer.logical.id, slowActiveServer.id)
        } catch {
            XCTFail("Unexpected error: \(error)")
        }
    }
}
