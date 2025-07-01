//
//  Created on 03/06/2024.
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

import Dependencies
import Domain
import Foundation

struct ConnectionConfiguration {
    let hostname: String
    let features: VPNConnectionFeatures
    let connectivity: Bool

    init(
        hostname: String,
        netshield: NetShieldType,
        vpnAccelerator: Bool,
        bouncing: String?,
        natType: NATType,
        safeMode: Bool?,
        connectivity: Bool
    ) {
        self.init(
            hostname: hostname,
            features: VPNConnectionFeatures(
                netshield: netshield,
                vpnAccelerator: vpnAccelerator,
                bouncing: bouncing,
                natType: natType,
                safeMode: safeMode
            ),
            connectivity: connectivity
        )
    }

    init(hostname: String, features: VPNConnectionFeatures, connectivity: Bool) {
        self.hostname = hostname
        self.features = features
        self.connectivity = connectivity
    }

    init(server: ServerEndpoint, features: VPNConnectionFeatures, connectivity: Bool) {
        self.hostname = server.domain
        self.features = features.copyWithChanged(bouncing: server.label)
        self.connectivity = connectivity
    }
}
