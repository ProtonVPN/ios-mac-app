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

public enum ServerTier: CaseIterable {
    case plus
    case basic
    case free
}

extension ServerTier {
    var title: String {
        switch self {
        case .basic:
            return LocalizedString.basicServers
        case .plus:
            return LocalizedString.plusServers
        case .free:
            return LocalizedString.freeServers
        }
    }
}

enum SearchResult {
    case countries([CountryViewModel])
    case servers(tier: ServerTier, servers: [ServerViewModel])
}

extension SearchResult {
    var title: String {
        switch self {
        case let .countries(data):
            return LocalizedString.searchResultsCountries("\(data.count)")
        case let .servers(tier: tier, servers: data):
            return "\(tier.title) (\(data.count))"
        }
    }

    var count: Int {
        switch self {
        case let .countries(data):
            return data.count
        case let .servers(tier: _, servers: data):
            return data.count
        }
    }
}
