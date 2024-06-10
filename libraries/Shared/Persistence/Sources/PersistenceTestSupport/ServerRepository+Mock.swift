//
//  Created on 12/06/2024.
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

import Persistence
import Domain

extension ServerRepository {
    public static func empty() -> Self {
        .init(serverCount: { 0 }, groups: { _, _ in [] })
    }
    public static func notEmpty() -> Self {
        .init(serverCount: { 1 }, groups: { _, _ in [] })
    }
    public static func emptyWithUpsert() -> Self {
        .init(serverCount: { 0 }, upsertServers: { _ in }, groups: { _, _ in [] })
    }
}

extension VPNServer {
    static var mock: Self {
        .init(logical: .mock, endpoints: [])
    }
}

extension Logical {
    static var mock: Self {
        .init(id: "",
              name: "",
              domain: "",
              load: 0,
              entryCountryCode: "",
              exitCountryCode: "",
              tier: 0,
              score: 0,
              status: 0,
              feature: [],
              city: nil,
              hostCountry: nil,
              translatedCity: nil,
              latitude: 0,
              longitude: 0,
              gatewayName: nil)
    }
}
