//
//  Created on 02/03/2024.
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

import PersistenceTestSupport
@testable import Persistence

/// This test case verifies that all tests operate on the same shared ephemeral database
final class CaseIsolatedTestCaseTests: CaseIsolatedDatabaseTestCase {

    static var expectedEntriesInDatabase = 0

    func testInsertingServer1() {
        repository.upsert(servers: [TestData.createMockServer(withID: "paid1", tier: 0)])
        Self.expectedEntriesInDatabase += 1
        XCTAssertEqual(repository.serverCount(), Self.expectedEntriesInDatabase)
    }

    func testInsertingServer2() {
        repository.upsert(servers: [TestData.createMockServer(withID: "free1", tier: 0)])
        Self.expectedEntriesInDatabase += 1
        XCTAssertEqual(repository.serverCount(), Self.expectedEntriesInDatabase)
    }
}

/// This test case verifies that all tests operate on their own ephemeral databases
final class TestIsolatedTestCaseTests: TestIsolatedDatabaseTestCase {

    func testInsertingServer1() {
        repository.upsert(servers: [TestData.createMockServer(withID: "paid1", tier: 0)])
        XCTAssertEqual(repository.serverCount(), 1)
    }

    func testInsertingServer2() {
        repository.upsert(servers: [TestData.createMockServer(withID: "free1", tier: 0)])
        XCTAssertEqual(repository.serverCount(), 1)
    }
}
