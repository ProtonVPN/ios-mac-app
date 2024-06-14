//
//  Created on 14/06/2024.
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

import Foundation
import Dependencies
import struct Domain.Server
import Connection
import Persistence

extension ServerIdentifier: DependencyKey {
    public static let liveValue: ServerIdentifier = .init(
        fullServerInfo: { logicalServerInfo in
            @Dependency(\.serverRepository) var repository
            let idFilter = VPNServerFilter.logicalID(logicalServerInfo.logicalID)
            guard let server = repository.getFirstServer(filteredBy: [idFilter], orderedBy: .none) else {
                return nil
            }
            guard let endpoint = server.endpoints.first(where: { $0.id == logicalServerInfo.serverID }) else {
                return nil
            }
            return Server(logical: server.logical, endpoint: endpoint)
        }
    )
}
