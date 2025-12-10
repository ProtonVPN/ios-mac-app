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
            TestData.createMockServer(withID: "UK#02", status: 1),
            TestData.createMockServer(withID: "UK#03", status: 0),
        ]

        repository.upsert(servers: mixedStatusServers)

        let group = try XCTUnwrap(repository.getGroups(filteredBy: [], groupedBy: .serverType).first)

        XCTAssertFalse(group.isUnderMaintenance)
    }

    func testMaintenanceWithAllUnderMaintenanceStatus() throws {
        let maintenanceServers = [
            TestData.createMockServer(withID: "UK#01", status: 0),
            TestData.createMockServer(withID: "UK#02", status: 0),
        ]

        repository.upsert(servers: maintenanceServers)

        let group = try XCTUnwrap(repository.getGroups(filteredBy: [], groupedBy: .serverType).first)

        XCTAssertTrue(group.isUnderMaintenance)
    }

    func testMaintenanceWithAllNormalStatus() throws {
        let normalStatusServers = [
            TestData.createMockServer(withID: "UK#01", status: 1),
            TestData.createMockServer(withID: "UK#02", status: 1),
            TestData.createMockServer(withID: "UK#03", status: 1),
        ]

        repository.upsert(servers: normalStatusServers)

        let group = try XCTUnwrap(repository.getGroups(filteredBy: [], groupedBy: .serverType).first)

        XCTAssertFalse(group.isUnderMaintenance)
    }

    func testGroupingByCityGroupsServersWithSameCityCountryCombination() throws {
        let servers = [
            TestData.createMockServer(withID: "FR#1", countryCode: "FR", city: "Paris"),
            TestData.createMockServer(withID: "FR#2", countryCode: "FR", city: "Paris"),
            TestData.createMockServer(withID: "FR#3", countryCode: "FR", city: "Lyon"),
        ]

        repository.upsert(servers: servers)

        let groups = try XCTUnwrap(repository.getGroups(filteredBy: [], groupedBy: .cityName))

        guard groups.count == 2 else {
            XCTFail("Expected 2 groups, got \(groups.count)")
            return
        }

        XCTAssertEqual(groups[0].serverCount, 1)
        XCTAssertEqual(groups[0].cityCount, 1)
        XCTAssertEqual(groups[0].kind, .city(countryCode: "FR", cityName: "Lyon"))

        XCTAssertEqual(groups[1].serverCount, 2)
        XCTAssertEqual(groups[1].cityCount, 1)
        XCTAssertEqual(groups[1].kind, .city(countryCode: "FR", cityName: "Paris"))
    }

    func testServersWithDifferentCountryAreNotGrouped() throws {
        let differentCountryServers = [
            TestData.createMockServer(withID: "FR#1", countryCode: "FR", city: "Paris"),
            TestData.createMockServer(withID: "US#1", countryCode: "US", city: "Paris"),
        ]

        repository.upsert(servers: differentCountryServers)

        let groups = try XCTUnwrap(repository.getGroups(filteredBy: [], groupedBy: .cityName))

        guard groups.count == 2 else {
            XCTFail("Expected 2 groups, got \(groups.count)")
            return
        }

        XCTAssertEqual(groups[0].cityCount, 1)
        XCTAssertEqual(groups[0].kind, .city(countryCode: "FR", cityName: "Paris"))

        XCTAssertEqual(groups[1].cityCount, 1)
        XCTAssertEqual(groups[1].kind, .city(countryCode: "US", cityName: "Paris"))
    }
}
