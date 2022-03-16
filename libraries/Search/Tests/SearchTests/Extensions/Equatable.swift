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

import Foundation
import UIKit
@testable import Search

extension SearchStatus: Equatable {
    public static func == (lhs: SearchStatus, rhs: SearchStatus) -> Bool {
        switch (lhs, rhs) {
        case (SearchStatus.placeholder, SearchStatus.placeholder):
            return true
        case let (SearchStatus.recentSearches(ldata), SearchStatus.recentSearches(rdata)):
            return rdata == ldata
        case (SearchStatus.noResults, SearchStatus.noResults):
            return true
        case let (SearchStatus.results(ldata), SearchStatus.results(rdata)):
            return ldata == rdata
        default:
            return false
        }
    }
}

extension SearchResult: Equatable {
    public static func == (lhs: SearchResult, rhs: SearchResult) -> Bool {
        switch (lhs, rhs) {
        case (SearchResult.upsell, SearchResult.upsell):
            return true
        case let (SearchResult.countries(countries: ldata), SearchResult.countries(countries: rdata)):
            return ldata.map({ $0 as! CountryViewModelMock }) == rdata.map({ $0 as! CountryViewModelMock })
        case let (SearchResult.servers(tier: ltier, servers: ldata), SearchResult.servers(tier: rtier, servers: rdata)):
            return ltier == rtier && ldata.map({ $0 as! ServerViewModelMock }) == rdata.map({ $0 as! ServerViewModelMock })
        case let (SearchResult.secureCoreCountries(servers: ldata), SearchResult.secureCoreCountries(servers: rdata)):
            return ldata.map({ $0 as! ServerViewModelMock }) == rdata.map({ $0 as! ServerViewModelMock })
        case let (SearchResult.cities(cities: ldata), SearchResult.cities(cities: rdata)):
            return ldata.map({ $0 as! CityViewModelMock }) == rdata.map({ $0 as! CityViewModelMock })
        default:
            return false
        }
    }
}

extension ServerViewModelMock: Equatable {
    static func == (lhs: ServerViewModelMock, rhs: ServerViewModelMock) -> Bool {
        return lhs.description == rhs.description
    }
}

extension CountryViewModelMock: Equatable {
    static func == (lhs: CountryViewModelMock, rhs: CountryViewModelMock) -> Bool {
        lhs.description == rhs.description
    }
}

extension CityViewModelMock: Equatable {
    static func == (lhs: CityViewModelMock, rhs: CityViewModelMock) -> Bool {
        return lhs.cityName == rhs.cityName
    }
}
