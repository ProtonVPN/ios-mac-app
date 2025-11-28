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

import Foundation
import Network

public extension NetworkInterface {
    internal static let localIpv4Ranges: [Range<IPv4Address>] = [
        IPv4Address("10.0.0.0")! ..< IPv4Address("10.255.255.255")!, // RFC1918
        IPv4Address("172.16.0.0")! ..< IPv4Address("172.31.255.255")!,
        IPv4Address("192.168.0.0")! ..< IPv4Address("192.168.255.255")!,
        IPv4Address("169.254.0.0")! ..< IPv4Address("169.254.255.255")!, // RFC3927
    ]

    var hasBadRanges: Bool {
        guard let ipv4 = addr as? IPv4Address else { return false }

        // We don't care about the interface if it isn't being used.
        guard flags.contains([.up, .running]) else { return false }

        // We don't care about point-to-point or loopback interfaces, we care about how we're reaching the WAN.
        guard flags.isDisjoint(with: [.pointToPoint, .loopback]) else { return false }

        guard let maskIpv4 = mask as? IPv4Address else { return false }

        let range = Range<IPv4Address>(ip: ipv4, netmask: maskIpv4)
        return !Self.localIpv4Ranges.contains { $0.isSuperSet(of: range) }
    }

    var ipv4SubnetDescription: String? {
        guard let addr = addr as? IPv4Address else { return nil }

        var result = String(describing: addr)
        if let mask = mask as? IPv4Address {
            result += "/\(mask.leadingOnesInMask)"
        }

        return result
    }
}

private extension Range {
    func isSuperSet(of other: Range<Bound>) -> Bool {
        lowerBound <= other.lowerBound &&
            other.upperBound <= upperBound
    }
}

extension IPv4Address: @retroactive Comparable {
    public static func < (lhs: IPv4Address, rhs: IPv4Address) -> Bool {
        lhs.rawValue.withUnsafeBytes { lhsBytes in
            rhs.rawValue.withUnsafeBytes { rhsBytes in
                memcmp(lhsBytes.baseAddress, rhsBytes.baseAddress, 4) < 0
            }
        }
    }
}

extension IPv4Address {
    var leadingOnesInMask: Int {
        var result = 0
        for byte in rawValue {
            guard byte != UInt8.max else {
                result += UInt8.bitWidth
                continue
            }

            result += (~byte).leadingZeroBitCount
            break
        }

        return result
    }
}

extension IPv6Address: @retroactive Comparable {
    public static func < (lhs: IPv6Address, rhs: IPv6Address) -> Bool {
        lhs.rawValue.withUnsafeBytes { lhsBytes in
            rhs.rawValue.withUnsafeBytes { rhsBytes in
                memcmp(lhsBytes.baseAddress, rhsBytes.baseAddress, 16) < 0
            }
        }
    }
}

extension Range<IPv4Address> {
    init(ip: IPv4Address, netmask: IPv4Address) {
        self = ip.rawValue.withUnsafeBytes { ipBytes in
            netmask.rawValue.withUnsafeBytes { netmaskBytes in
                let ipValue = ipBytes.assumingMemoryBound(to: UInt32.self).baseAddress?.pointee ?? 0
                let netmaskValue = netmaskBytes.assumingMemoryBound(to: UInt32.self).baseAddress?.pointee ?? 0

                var low = ipValue & netmaskValue
                var hi = low | ~netmaskValue

                let lowData = Data(bytes: &low, count: MemoryLayout<UInt32>.size)
                let hiData = Data(bytes: &hi, count: MemoryLayout<UInt32>.size)

                return IPv4Address(lowData)! ..< IPv4Address(hiData)!
            }
        }
    }
}
