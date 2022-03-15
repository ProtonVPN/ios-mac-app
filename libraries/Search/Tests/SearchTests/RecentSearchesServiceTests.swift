//
//  Created on 14.03.2022.
//
//  Copyright (c) 2022 Proton AG
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
@testable import Search

final class RecentSearchesServiceTests: XCTestCase {
    func testRecentSearchesShouldBeInitiallyEmpty() {
        let service = RecentSearchesService(storage: SearchStorageMock())
        XCTAssertTrue(service.get().isEmpty)
    }

    func testRecentSearchesReturnStoredItems() {
        let service = RecentSearchesService(storage: SearchStorageMock())
        service.add(searchText: "One")
        XCTAssertEqual(service.get(), ["One"])
    }

    func testRecentSearchesStoredItemsShouldBeCleared() {
        let service = RecentSearchesService(storage: SearchStorageMock())
        service.add(searchText: "One")
        service.add(searchText: "Two")
        service.clear()
        XCTAssertTrue(service.get().isEmpty)
    }

    func testRecentSearchesReturnStoredItemsInReverseOrder() {
        let service = RecentSearchesService(storage: SearchStorageMock())
        service.add(searchText: "One")
        service.add(searchText: "Two")
        service.add(searchText: "Three")
        XCTAssertEqual(service.get(), ["Three", "Two", "One"])
    }

    func testRecentSearchesAreLimitedToFiveLatest() {
        let service = RecentSearchesService(storage: SearchStorageMock())
        service.add(searchText: "One")
        service.add(searchText: "Two")
        service.add(searchText: "Three")
        service.add(searchText: "Four")
        service.add(searchText: "Five")
        service.add(searchText: "Six")
        service.add(searchText: "Seven")
        XCTAssertEqual(service.get(), ["Seven", "Six", "Five", "Four", "Three"])
    }

    func testRecentSearchesExistingItemShouldPropagateToTheTopInsteadOfGettingDuplicated() {
        let service = RecentSearchesService(storage: SearchStorageMock())
        service.add(searchText: "One")
        service.add(searchText: "Two")
        service.add(searchText: "Three")
        service.add(searchText: "Two")
        XCTAssertEqual(service.get(), ["Two", "Three", "One"])
    }
}
