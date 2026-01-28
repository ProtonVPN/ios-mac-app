//
//  Created on 28/01/2026 by Chris Janusiewicz.
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

import CommonNetworking
import Dependencies
import Domain
import Persistence

extension ServerWrapper {
    public var server: ServerModel {
        @Dependency(\.serverRepository) var serverRepository: ServerRepository
        if let vpnServer = serverRepository.getFirstServer(
            filteredBy: [.logicalID(_server.id)],
            orderedBy: .fastest
        ) {
            return ServerModel(server: vpnServer)
        } else {
            fatalError()
        }
    }

    static func == (lhs: ServerWrapper, rhs: ServerWrapper) -> Bool {
        lhs.server == rhs.server
    }
}
