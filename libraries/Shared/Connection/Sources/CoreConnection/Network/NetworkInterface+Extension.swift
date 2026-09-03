//
//  Created on 28/11/2025 by Max Kupetskyi.
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

import Ergonomics
import Network
import NetworkingErgonomics

public extension NetworkInterface {
    /// Whether an active, non-loopback interface sits on a subnet outside the private and link-local ranges. Used for
    /// guarding against TunnelVision-style exploits that leverage DHCP option 121.
    var hasBadRanges: Bool {
        guard let address = addr as? IPv4Address, let mask = mask as? IPv4Address else { return false }

        // We don't care about the interface if it isn't being used.
        guard flags.contains([.up, .running]) else { return false }

        // We don't care about point-to-point or loopback interfaces, we care about how we're reaching the WAN.
        guard flags.isDisjoint(with: [.pointToPoint, .loopback]) else { return false }

        let subnet = IPv4Block(network: address.packed & mask.packed, prefixLength: mask.prefixLength)
        return !Self.localBlocks.contains { $0.contains(subnet) }
    }

    var ipv4SubnetDescription: String? {
        guard let address = addr as? IPv4Address else { return nil }
        guard let mask = mask as? IPv4Address else { return "\(address)" }
        return "\(address)/\(mask.prefixLength)"
    }

    /// RFC 1918 private use and RFC 3927 link-local, the ranges a LAN interface is expected to live in.
    private static let localBlocks = IPv4Block.privateUse + [.linkLocal]
}
