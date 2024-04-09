//
//  Created on 27/01/2024.
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

import Dependencies

import Domain
import PersistenceTestSupport
@testable import Persistence

final class ServerDeletionTests: TestIsolatedDatabaseTestCase {

    func testDeleteStalePaidServers() throws {
        repository.upsert(
            servers: [
                TestData.createMockServer(withID: "free1", tier: 0),
                TestData.createMockServer(withID: "stale1", tier: 0),
                TestData.createMockServer(withID: "paid1", tier: 1),
                TestData.createMockServer(withID: "stale2", tier: 2)
            ]
        )

        let deletedServerCount = repository.delete(
            serversWithIDsNotIn: Set(arrayLiteral: "free1", "paid1"),
            maxTier: 0
        )

        XCTAssertEqual(deletedServerCount, 1)

        let remainingServers = repository.getServers(filteredBy: [], orderedBy: .nameAscending)
        let remainingServerIDs = remainingServers.map { $0.logical.id }

        // stale1 should be deleted since it matches the tier criteria and its ID is not in the list
        XCTAssertEqual(remainingServerIDs, ["free1", "paid1", "stale2"])
    }
}
