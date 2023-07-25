//
//  Created on 2023-07-05.
//
//  Copyright (c) 2023 Proton AG
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
import Combine
import VPNAppCore

public struct VpnServerGetter {
    public static let getServerById: @Sendable (String) -> AnyPublisher<VpnServer, Never> = { serverId in
        let serverStorage = Container.sharedContainer.makeServerStorage()
        return serverStorage.allServersPublisher.compactMap { servers in
            return servers.first(where: { server in
                server.id == serverId
            })
        }
        .map { $0.toVpnServer }
        .eraseToAnyPublisher()
    }
}

private extension ServerModel {
    var toVpnServer: VpnServer {
        VpnServer(
            id: self.id,
            name: self.name,
            domain: self.domain,
            load: self.load,
            entryCountryCode: self.entryCountryCode,
            exitCountryCode: self.exitCountryCode,
            tier: self.tier,
            score: self.score,
            status: self.status,
            feature: self.feature,
            city: self.city,
            hostCountry: self.hostCountry,
            translatedCity: self.translatedCity)
    }
}
