//
//  Created on 03.03.2022.
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

enum SearchResult {
    case countries([(Country, [Server])])
}

extension SearchResult {
    var title: String {
        switch self {
        case let .countries(data):
            return LocalizedString.searchResultsCountries("\(data.count)")
        }
    }

    var count: Int {
        switch self {
        case let .countries(data):
            return data.count
        }
    }
}
