//
//  Created on 01/07/2024.
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

import CustomDump
import struct Domain.AgentTunnelFeatures
import struct Domain.Server
import Ergonomics
import Foundation

// For now, let's override the dump descriptions with minimal info so `_printChanges` reducer is easier to read
extension Domain.Server: @retroactive CustomDumpStringConvertible {
    public var customDumpDescription: String {
        "Server(name: \(logical.name))"
    }
}

extension Domain.AgentTunnelFeatures: @retroactive CustomDumpStringConvertible {
    public var customDumpDescription: String {
        "AgentTunnelFeatures(netShield: \(netshield), vpnAccelerator: \(vpnAccelerator), natType: \(natType))"
    }
}
