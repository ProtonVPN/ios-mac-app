//
//  Created on 2021-12-09.
//
//  Copyright (c) 2021 Proton AG
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
import Crypto_VPN

extension LocalAgentFeatures {   
    var vpnFeatures: VPNConnectionFeatures? {
        guard let netshield = self.netshield, let vpnAccelerator = self.vpnAccelerator, let natType = self.natType, let safeMode = self.safeMode else {
            return nil
        }
        return VPNConnectionFeatures(netshield: netshield, vpnAccelerator: vpnAccelerator, bouncing: bouncing, natType: natType, safeMode: safeMode)
    }
    
}
