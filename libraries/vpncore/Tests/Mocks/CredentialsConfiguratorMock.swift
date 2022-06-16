//
//  Created on 2022-06-16.
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
import NetworkExtension

class VpnCredentialsConfiguratorMock: VpnCredentialsConfigurator {
    let vpnProtocol: VpnProtocol

    init(vpnProtocol: VpnProtocol) {
        self.vpnProtocol = vpnProtocol
    }

    func prepareCredentials(for protocolConfig: NEVPNProtocol,
                            configuration: VpnManagerConfiguration,
                            completionHandler: @escaping (NEVPNProtocol) -> Void) {
        assert(vpnProtocol == configuration.vpnProtocol, "Vpn protocol in configuration did not match!")

        switch vpnProtocol {
        case .ike:
            break
        case .openVpn:
            break
        case .wireGuard:
            break
        }

        completionHandler(protocolConfig)
    }
}
