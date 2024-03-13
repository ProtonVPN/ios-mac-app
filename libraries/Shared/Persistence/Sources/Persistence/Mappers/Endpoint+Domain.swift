//
//  Created on 21/12/2023.
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

import Domain

extension Domain.ServerEndpoint {

    init(server: Endpoint, overrides: EndpointOverrides?) {
        self.init(
            id: server.id,
            entryIp: server.entryIp,
            exitIp: server.exitIp,
            domain: server.domain,
            status: server.status,
            label: server.label,
            x25519PublicKey: server.x25519PublicKey,
            protocolEntries: overrides?.protocolEntries
        )
    }

    var overrideInfo: EndpointOverrides? {
        guard let protocolEntries else { return nil }

        return EndpointOverrides(
            endpointId: id,
            protocolMask: supportedProtocols.rawValue,
            protocolEntries: protocolEntries
        )
    }
}
