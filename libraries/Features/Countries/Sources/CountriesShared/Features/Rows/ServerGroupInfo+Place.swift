//
//  Created on 10/08/2026 by Max Kupetskyi.
//
//  Copyright (c) 2026 Proton AG
//
//  Proton VPN is free software: you can redistribute it and/or modify
//  it under the terms of the GNU General Public License as published by
//  the Free Software Foundation, either version 3 of the License, or
//  (at your option) any later version.
//
//  Proton VPN is distributed in the hope that it will be useful,
//  but WITHOUT ANY WARRANTY; without even the implied warranty of
//  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
//  GNU General Public License for more details.
//
//  You should have received a copy of the GNU General Public License
//  along with Proton VPN.  If not, see <https://www.gnu.org/licenses/>.

import Domain

extension Logical {
    func isInCountry(_ code: String) -> Bool {
        kind == .country && exitCountryCode == code
    }

    func isInCity(_ name: String, countryCode: String) -> Bool {
        isInCountry(countryCode) && city == name
    }

    func isInState(_ name: String, countryCode: String) -> Bool {
        isInCountry(countryCode) && state == name
    }
}

public extension ServerGroupInfo.Kind {
    func holds(_ logical: Logical) -> Bool {
        switch self {
        case let .country(code):
            logical.isInCountry(code)

        case let .gateway(name):
            logical.kind == .gateway(name: name)

        case let .city(name, code):
            logical.isInCity(name, countryCode: code)

        case let .state(name, code):
            logical.isInState(name, countryCode: code)
        }
    }

    /// Whether a request for `location` is a request for this place.
    ///
    /// Reads the parts that name the place and ignores the rest, because the same place can be asked
    /// for in more than one way. Ordering is the caller's preference among the servers here, not a
    /// different destination, so `.fastest` and `.random` both count.
    func matches(location: ConnectionSpec.Location) -> Bool {
        switch (self, location) {
        case let (.country(code), .country(requestedCode, _)):
            code == requestedCode

        case let (.gateway(name), .gateway(requestedName)):
            name == requestedName

        case let (.city(name, code), .city(requestedName, requestedCode, _)):
            name == requestedName && code == requestedCode

        case let (.state(name, code), .state(requestedName, requestedCode, _)):
            name == requestedName && code == requestedCode

        default:
            false
        }
    }
}

extension ServerGroupInfo {
    /// Whether `logical` is one of the servers this group holds.
    func matchesLogical(_ logical: Logical) -> Bool {
        if case let .country(code) = kind, featureIntersection == .secureCore {
            guard case .secureCore = logical.kind else {
                return false
            }
            return logical.exitCountryCode == code
        }
        return kind.holds(logical)
    }

    func matches(location: ConnectionSpec.Location, logical: Logical?) -> Bool {
        switch location {
        case .country, .city, .state, .gateway:
            kind.matches(location: location)

        // A Secure Core request names the country it exits, which is what a Secure Core group lists.
        case let .secureCore(.anyHop(to, _)), let .secureCore(.hop(to, _)):
            kind == .country(code: to)

        // These name no place of their own, so only the server the app picked can answer.
        case .any, .exact, .secureCore(.any):
            logical.map { matchesLogical($0) } ?? false
        }
    }
}
