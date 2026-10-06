//
//  Created on 21/08/2026.
//
//  Copyright (c) 2026 Proton AG
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

// Wire-format constants for reading IP packets: header layouts, protocol numbers, and the message types and ports of
// the protocols a packet filter has to recognize.

/// An IP version. The raw value is the version nibble that opens every IP header.
public enum IPVersion: UInt8, Sendable {
    case v4 = 4
    case v6 = 6
}

/// Transport protocol numbers, as carried in the IPv4 protocol field and the IPv6 next-header field.
public enum IPProtocol: UInt8 {
    case icmpV4 = 1
    case udp = 17
    case icmpV6 = 58
}

/// The IPv6 extension headers that can sit between the IP header and the transport (RFC 8200, RFC 4302).
public enum IPv6ExtensionHeader: UInt8 {
    case hopByHop = 0
    case routing = 43
    case fragment = 44
    case authentication = 51
    case destinationOptions = 60

    /// The whole header's length in bytes, from its length field. The field counts units past a fixed first part:
    /// 8-byte units past the first for the options and routing headers, 4-byte units past the first two for the
    /// authentication header. The fragment header is fixed and has no length field.
    public func totalLength(lengthField: UInt8) -> Int {
        switch self {
        case .hopByHop, .routing, .destinationOptions:
            (Int(lengthField) + 1) * 8
        case .fragment:
            8
        case .authentication:
            (Int(lengthField) + 2) * 4
        }
    }
}

/// Fixed layout facts about the IPv4 header (RFC 791).
public enum IPv4Header {
    /// The header's length without options.
    public static let minimumLength = 20
    /// Byte offset of the destination address.
    public static let destinationOffset = 16
    /// Masks the fragment offset out of the flags-and-offset field. A nonzero offset marks a later fragment.
    public static let fragmentOffsetMask: UInt16 = 0x1FFF
}

/// Fixed layout facts about the IPv6 header (RFC 8200).
public enum IPv6Header {
    /// The header's length. IPv6 headers carry no options, so it never varies.
    public static let length = 40
    /// Byte offset of the destination address.
    public static let destinationOffset = 24
    /// Masks the fragment offset out of the fragment header's offset-and-flags field.
    public static let fragmentOffsetMask: UInt16 = 0xFFF8
}

/// Fixed layout facts about the UDP header (RFC 768).
public enum UDPHeader {
    /// The header's length: two ports, a length, and a checksum.
    public static let length = 8
}

/// ICMPv4 message types (RFC 792).
public enum ICMPv4Type: UInt8 {
    case destinationUnreachable = 3
}

/// ICMPv6 message types (RFC 4443, RFC 4861).
public enum ICMPv6Type: UInt8 {
    case packetTooBig = 2
    case routerSolicitation = 133
    case routerAdvertisement = 134
    case neighborSolicitation = 135
    case neighborAdvertisement = 136
    case redirect = 137

    /// Whether the message belongs to router or neighbor discovery (RFC 4861).
    public var isNeighborDiscovery: Bool {
        switch self {
        case .routerSolicitation, .routerAdvertisement, .neighborSolicitation, .neighborAdvertisement, .redirect:
            true
        case .packetTooBig:
            false
        }
    }

    /// RFC 4861 requires every discovery message to carry this hop limit, so a receiver can tell it came from the link
    /// and not from a router beyond it.
    public static let neighborDiscoveryHopLimit: UInt8 = 255
}

/// Layout of the ICMP error messages that report about another packet (RFC 792, RFC 4443).
public enum ICMPErrorMessage {
    /// The reported packet's header follows the type, code, checksum, and one 32-bit field.
    public static let invokedPacketOffset = 8
}

/// DHCPv4 (RFC 2131).
public enum DHCPv4 {
    /// Server port 67 and client port 68.
    public static let ports: ClosedRange<UInt16> = 67 ... 68
    /// The cookie every message carries after the fixed BOOTP fields.
    public static let magicCookie: UInt32 = 0x6382_5363
    /// Byte offset of the cookie from the start of the message.
    public static let magicCookieOffset = 236
}

/// DHCPv6 (RFC 8415).
public enum DHCPv6 {
    /// Client port 546 and server port 547.
    public static let ports: ClosedRange<UInt16> = 546 ... 547
    /// SOLICIT through the end of the message type registry.
    public static let messageTypes: ClosedRange<UInt8> = 1 ... 36
}

/// A CIDR block over an IPv4 address in host-order integer form.
public struct IPv4Block: Equatable, Sendable {
    /// The block's first address, in host order, with the host bits already zero.
    public let network: UInt32
    /// How many leading bits of an address must match `network`.
    public let prefixLength: Int

    public init(network: UInt32, prefixLength: Int) {
        self.network = network
        self.prefixLength = prefixLength
    }

    /// Whether the address, in host order, falls inside the block.
    public func contains(_ address: UInt32) -> Bool {
        let mask = ~UInt32(0) << (32 - prefixLength)
        return address & mask == network
    }

    /// Whether every address in `other` also falls inside this block.
    public func contains(_ other: IPv4Block) -> Bool {
        prefixLength <= other.prefixLength && contains(other.network)
    }

    /// RFC 1918 private-use space.
    public static let privateUse = [
        IPv4Block(network: 0x0A00_0000, prefixLength: 8), // 10.0.0.0/8
        IPv4Block(network: 0xAC10_0000, prefixLength: 12), // 172.16.0.0/12
        IPv4Block(network: 0xC0A8_0000, prefixLength: 16), // 192.168.0.0/16
    ]

    /// Link-local space (RFC 3927), which hosts pick for themselves when nothing assigns them an address.
    public static let linkLocal = IPv4Block(network: 0xA9FE_0000, prefixLength: 16) // 169.254.0.0/16

    /// Multicast space (RFC 5771).
    public static let multicast = IPv4Block(network: 0xE000_0000, prefixLength: 4) // 224.0.0.0/4

    /// The limited broadcast address (RFC 919), which never leaves the link.
    public static let limitedBroadcast = IPv4Block(network: 0xFFFF_FFFF, prefixLength: 32) // 255.255.255.255

    /// Every range that counts as the local network: private use, link-local, multicast, and limited broadcast.
    public static let localNetworks = privateUse + [linkLocal, multicast, limitedBroadcast]
}

/// A CIDR block over an IPv6 address, in host-order integer form. Only the first 64 bits take part, which covers every
/// block the packet filter distinguishes.
public struct IPv6Block: Equatable, Sendable {
    /// The block's first 64 bits, in host order, with the host bits already zero.
    public let network: UInt64
    /// How many leading bits of an address must match `network`, at most 64.
    public let prefixLength: Int

    public init(network: UInt64, prefixLength: Int) {
        self.network = network
        self.prefixLength = prefixLength
    }

    /// Whether an address whose first 64 bits are `high`, in host order, falls inside the block.
    public func contains(high: UInt64) -> Bool {
        let mask = ~UInt64(0) << (64 - prefixLength)
        return high & mask == network
    }

    /// Link-local space (RFC 4291).
    public static let linkLocal = IPv6Block(network: 0xFE80_0000_0000_0000, prefixLength: 10) // fe80::/10

    /// Unique local space (RFC 4193), the IPv6 counterpart of private use.
    public static let uniqueLocal = IPv6Block(network: 0xFC00_0000_0000_0000, prefixLength: 7) // fc00::/7

    /// Multicast space (RFC 4291).
    public static let multicast = IPv6Block(network: 0xFF00_0000_0000_0000, prefixLength: 8) // ff00::/8

    /// Every range that counts as the local network: link-local, unique local, and multicast.
    public static let localNetworks = [linkLocal, uniqueLocal, multicast]
}
