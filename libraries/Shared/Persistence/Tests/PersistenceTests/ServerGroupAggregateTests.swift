//
//  Created on 05/04/2024.
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

import Persistence
import PersistenceTestSupport

final class ServerGroupAggregateTests: TestIsolatedDatabaseTestCase {

    func testMaintenanceWithMixedStatus() throws {
        let mixedStatusServers = [
            TestData.createMockServer(withID: "UK#01", status: 0),
            TestData.createMockServer(withID: "UK#02", status: 1)
        ]

        repository.upsert(servers: mixedStatusServers)

        let group = try XCTUnwrap(repository.getGroups(filteredBy: []).first)

        XCTAssertEqual(group.isUnderMaintenance, false)
    }

    func testMaintenanceWithMaintenanceStatus() throws {
        let mixedStatusServers = [
            TestData.createMockServer(withID: "UK#01", status: 0),
            TestData.createMockServer(withID: "UK#02", status: 0)
        ]

        repository.upsert(servers: mixedStatusServers)

        let group = try XCTUnwrap(repository.getGroups(filteredBy: []).first)

        XCTAssertEqual(group.isUnderMaintenance, true)
    }

}
