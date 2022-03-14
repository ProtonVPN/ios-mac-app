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

final class SearchViewModelTests: XCTestCase {
    func testInitialStateIsEmptyWhenNoRecentSearchesArePresent() {
        let vm = SearchViewModel(recentSearchesService: RecentSearchesService(storage: SearchStorageMock()), data: [], constants: Constants(numberOfCountries: 61), mode: .freeUser)
        XCTAssertEqual(vm.status, SearchStatus.placeholder)
    }

    func testInitialStateIsRecentSearchesWhenPresent() {
        let service = RecentSearchesService(storage: SearchStorageMock())
        service.add(searchText: "One")
        service.add(searchText: "Two")
        let vm = SearchViewModel(recentSearchesService: service, data: [], constants: Constants(numberOfCountries: 61), mode: .freeUser)
        XCTAssertEqual(vm.status, SearchStatus.recentSearches(["Two", "One"]))
    }

    func testClearingRecentSearchesGoesToPlaceholderState() {
        let service = RecentSearchesService(storage: SearchStorageMock())
        service.add(searchText: "One")
        service.add(searchText: "Two")
        let vm = SearchViewModel(recentSearchesService: service, data: [], constants: Constants(numberOfCountries: 61), mode: .freeUser)
        vm.clearRecentSearches()
        XCTAssertEqual(vm.status, SearchStatus.placeholder)
    }

    func testAddingRecentSearchSavesIt() {
        let service = RecentSearchesService(storage: SearchStorageMock())
        let vm = SearchViewModel(recentSearchesService: service, data: [], constants: Constants(numberOfCountries: 61), mode: .freeUser)
        vm.saveSearch(searchText: "One")
        XCTAssertEqual(service.get(), ["One"])
    }

    func testNothingIsFoundWithEmptyData() {
        let vm = SearchViewModel(recentSearchesService: RecentSearchesService(storage: SearchStorageMock()), data: [], constants: Constants(numberOfCountries: 61), mode: .freeUser)
        vm.search(searchText: "Fra")
        XCTAssertEqual(vm.status, SearchStatus.noResults)
    }
}

extension SearchStatus: Equatable {
    public static func == (lhs: SearchStatus, rhs: SearchStatus) -> Bool {
        switch (lhs, rhs) {
        case (SearchStatus.placeholder, SearchStatus.placeholder):
            return true
        case let (SearchStatus.recentSearches(ldata), SearchStatus.recentSearches(rdata)):
            return rdata == ldata
        case (SearchStatus.noResults, SearchStatus.noResults):
            return true
        default:
            return false
        }
    }
}
