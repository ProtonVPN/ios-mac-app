//
//  Created on 20/09/2025 by Adam Viaud.
//
//  Copyright (c) 2025 Proton AG
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

import NetworkExtension

extension NEAppProxyTCPFlow {
    /// Returns the correct remote endpoint for both < macOS 15 and ≥ macOS 15.
    var remoteEndpoint: NWEndpoint? {
        if #available(macOS 15, *) {
            self.remoteFlowEndpoint
        } else {
            value(forKey: "remoteEndpoint") as? NWEndpoint
        }
    }
}

extension NEAppProxyUDPFlow {
    /// Returns the correct local endpoint for both < macOS 15 and ≥ macOS 15.
    var localEndpoint: NWEndpoint? {
        if #available(macOS 15, *) {
            self.localFlowEndpoint
        } else {
            value(forKey: "localEndpoint") as? NWEndpoint
        }
    }
}
