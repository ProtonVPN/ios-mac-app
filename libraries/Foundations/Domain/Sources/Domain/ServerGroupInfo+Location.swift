//
//  Created on 2026-02-02 by Pawel Jurczyk.
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

public extension ServerGroupInfo.Kind {
    func locationWithOrder(_ order: ConnectionSpec.SelectionSpec = .fastest) -> ConnectionSpec.Location {
        switch self {
        case let .city(name, code):
            .city(name: name, code: code, order: order)
        case let .state(name, code):
            .state(name: name, code: code, order: order)
        case let .country(code):
            .country(code: code, order: order)
        case let .gateway(name):
            .gateway(name: name)
        }
    }
}
