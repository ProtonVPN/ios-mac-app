//
//  Created on 11/08/2026.
//
//  Copyright (c) 2026 Proton AG
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

import Domain
@testable import Persistence
import PersistenceTestSupport
import XCTest

final class GroupOrderingTests: CaseIsolatedDatabaseTestCase {
    override class func setUp() {
        super.setUp()
        // A German-language fixture. The display names are Évora, Köln, Naples, Warschau, Wien. Raw
        // byte order would list Vienna before Warsaw and sink Évora below Z.
        let servers = [
            TestData.createMockServer(withID: "de-1", countryCode: "DE", city: "Cologne", translatedCity: "Köln"),
            TestData.createMockServer(withID: "de-2", countryCode: "DE", city: "Vienna", translatedCity: "Wien"),
            TestData.createMockServer(withID: "de-3", countryCode: "DE", city: "Warsaw", translatedCity: "Warschau"),
            TestData.createMockServer(withID: "de-4", countryCode: "DE", city: "Naples"),
            TestData.createMockServer(withID: "de-5", countryCode: "DE", city: "Évora"),
        ]
        internalRepository!.upsert(servers: servers)
    }

    func testCityGroupsFollowDisplayNameOrder() {
        let groups = repository.getGroups(
            filteredBy: [],
            groupedBy: .cityName,
            orderedBy: .localizedGroupNameAscending
        )

        XCTAssertEqual(groups.map(\.kind.name), ["Évora", "Cologne", "Naples", "Warsaw", "Vienna"])
    }
}
