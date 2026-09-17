//
//  Created on 21/08/2026.
//
//  Copyright (c) 2026 Proton AG
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

#if os(macOS)
    import Ergonomics
    import Foundation
    import Network
    import NetworkExtension
    import NetworkingErgonomics

    /// What the packet filter enforces: the tunnel interface, whose packets always pass, and the servers the tunnel's
    /// transport talks to. The coordinator packs a policy into a ``Lookup`` on each update.
    struct PacketFilterPolicy: Equatable, Sendable {
        /// The kernel's index for the tunnel interface, or 0 while there is no tunnel.
        var tunnelInterfaceIndex: UInt32
        var endpointsV4: Set<IPv4Address>
        var endpointsV6: Set<IPv6Address>

        /// Whether packets to and from local networks stay allowed, following the LAN preference recorded on the
        /// provider configuration (`excludeLocalNetworks`).
        var allowsLocalNetworks: Bool

        /// Blocks everything except necessary traffic for keeping the network working, plus the local network when
        /// `allowsLocalNetworks` is set.
        static func emptyPolicy(allowsLocalNetworks: Bool) -> PacketFilterPolicy {
            PacketFilterPolicy(
                tunnelInterfaceIndex: 0,
                endpointsV4: [],
                endpointsV6: [],
                allowsLocalNetworks: allowsLocalNetworks
            )
        }

        /// The policy in place before the tunnel reports anything. It blocks, and does not assume LAN access.
        static let failClosed = emptyPolicy(allowsLocalNetworks: false)
    }

    // MARK: - Packed addresses

    /// A packed address that avoids marshalling to Foundation types for performance reasons.
    enum PackedIPAddress: Hashable, Sendable {
        case v4(UInt32)
        case v6(hi: UInt64, lo: UInt64)

        init(_ address: IPv4Address) {
            self = .v4(address.packed)
        }

        init(_ address: IPv6Address) {
            let packed = address.packed
            self = .v6(hi: packed.hi, lo: packed.lo)
        }

        /// Whether the address belongs to a local network: private use, link-local, multicast, or limited broadcast for
        /// IPv4, and link-local, unique local, or multicast for IPv6.
        var isLocalNetwork: Bool {
            switch self {
            case let .v4(value):
                IPv4Block.localNetworks.contains { $0.contains(value) }
            case let .v6(hi, _):
                IPv6Block.localNetworks.contains { $0.contains(high: hi) }
            }
        }
    }

    // MARK: - Lookup form

    extension PacketFilterPolicy {
        /// A packet filter policy that packs the endpoint addresses into integers to check packets without needing to
        /// run string comparisons on IP addresses.
        struct Lookup: Sendable {
            let endpoints: Set<PackedIPAddress>
            let allowsLocalNetworks: Bool
            let tunnelInterfaceIndex: UInt32

            init(_ policy: PacketFilterPolicy) {
                let packed = policy.endpointsV4.map { PackedIPAddress($0) }
                    + policy.endpointsV6.map { PackedIPAddress($0) }
                self.endpoints = Set(packed)
                self.allowsLocalNetworks = policy.allowsLocalNetworks
                self.tunnelInterfaceIndex = policy.tunnelInterfaceIndex
            }

            /// Whether the packet traveled the tunnel interface.
            func isTunnel(_ interfaceIndex: UInt32) -> Bool {
                interfaceIndex != 0 && interfaceIndex == tunnelInterfaceIndex
            }

            /// Whether the policy allows a parsed packet.
            func allows(_ packet: ParsedPacket, direction: NETrafficDirection) -> Bool {
                switch packet.payload {
                case .dhcpV4, .dhcpV6:
                    // DHCP keeps the underlying network attachment alive. While DHCP replies may come from any server,
                    // outgoing packets should always be sent over the local network.
                    return direction == .inbound || packet.destination.isLocalNetwork
                case let .neighborDiscovery(hopLimit):
                    // Neighbor discovery lets the link resolve neighbors. The hop limit shows the packet came from the
                    // link and not from beyond a router.
                    return hopLimit == ICMPv6Type.neighborDiscoveryHopLimit &&
                        isLocalNetwork(packet, direction: direction)
                case let .pathError(invokedDestination):
                    // Routers on the path report unreachable and too-big errors, which the tunnel transport needs to
                    // learn the path MTU. Reject any other traffic.
                    let aboutTheTunnel = invokedDestination.map(endpoints.contains) ?? false
                    return direction != .outbound && aboutTheTunnel
                case .other:
                    if allowsLocalNetworks, isLocalNetwork(packet, direction: direction) {
                        return true
                    }
                    return matches(packet, direction: direction)
                }
            }

            private func matches(_ packet: ParsedPacket, direction: NETrafficDirection) -> Bool {
                switch direction {
                case .outbound:
                    endpoints.contains(packet.destination)
                case .inbound:
                    endpoints.contains(packet.source)
                case .any:
                    endpoints.contains(packet.destination) || endpoints.contains(packet.source)
                @unknown default:
                    endpoints.contains(packet.destination) || endpoints.contains(packet.source)
                }
            }

            private func isLocalNetwork(_ packet: ParsedPacket, direction: NETrafficDirection) -> Bool {
                switch direction {
                case .outbound:
                    packet.destination.isLocalNetwork
                case .inbound:
                    packet.source.isLocalNetwork
                case .any:
                    packet.destination.isLocalNetwork || packet.source.isLocalNetwork
                @unknown default:
                    packet.destination.isLocalNetwork || packet.source.isLocalNetwork
                }
            }
        }
    }

    // MARK: - Drop counts

    /// What the filter dropped since the last report.
    struct DroppedPacketCounts: Equatable, Sendable, CustomStringConvertible {
        /// Packets that parsed and that the policy did not allow.
        var blocked = 0
        /// Packets that did not parse as IPv4 or IPv6 with a readable header.
        var unparseable = 0

        /// Returns the drops so far and starts counting again from zero.
        mutating func take() -> DroppedPacketCounts {
            let taken = self
            self = DroppedPacketCounts()
            return taken
        }

        var description: String {
            "\(blocked) blocked, \(unparseable) unparseable"
        }
    }

    // MARK: - Packet parsing

    /// The fields the policy reads out of one IP packet, with the transport classified as far as the policy cares.
    struct ParsedPacket: Equatable, Sendable {
        enum Payload: Equatable, Sendable {
            /// UDP on the DHCPv4 ports carrying the BOOTP magic cookie.
            case dhcpV4
            /// UDP on the DHCPv6 ports carrying a known message type.
            case dhcpV6
            /// ICMPv6 router or neighbor discovery, with the hop limit the packet traveled with.
            case neighborDiscovery(hopLimit: UInt8)
            /// An ICMP error report, with the destination of the packet that provoked it when the report carried enough
            /// of that packet to read it.
            case pathError(invokedDestination: PackedIPAddress?)
            /// Any other transport, a later fragment whose transport header traveled with the first one, or a transport
            /// header cut short.
            case other
        }

        let source: PackedIPAddress
        let destination: PackedIPAddress
        let payload: Payload

        /// The most extension headers the walk follows before giving up on finding the transport.
        private static let maximumExtensionHeaders = 8

        /// Parses a packet.
        init?(_ packet: RawSpan) {
            let parsed = try? BinaryDecoder<Mapped>.decode(slicing: packet) { reader in
                try Self.parse(&reader)
            }
            guard let parsed else { return nil }
            self = parsed
        }

        private init(source: PackedIPAddress, destination: PackedIPAddress, payload: Payload) {
            self.source = source
            self.destination = destination
            self.payload = payload
        }

        private static func parse(_ reader: inout BinaryDecoder<Mapped>) throws -> ParsedPacket? {
            let versionAndHeaderLength: UInt8 = try reader.read()
            switch IPVersion(rawValue: versionAndHeaderLength >> 4) {
            case .v4:
                let headerLength = Int(versionAndHeaderLength & 0x0F) * 4
                guard headerLength >= IPv4Header.minimumLength else { return nil }
                try reader.skip(5) // type of service, total length, identification
                let flagsAndFragmentOffset = try reader.readBigEndian(UInt16.self)
                try reader.skip(1) // time to live
                let proto: UInt8 = try reader.read()
                try reader.skip(2) // header checksum
                let source = try PackedIPAddress.v4(reader.readBigEndian(UInt32.self))
                let destination = try PackedIPAddress.v4(reader.readBigEndian(UInt32.self))
                try reader.skip(headerLength - IPv4Header.minimumLength) // options
                let isFirstFragment = flagsAndFragmentOffset & IPv4Header.fragmentOffsetMask == 0
                return ParsedPacket(
                    source: source,
                    destination: destination,
                    payload: isFirstFragment ? transport(IPProtocol(rawValue: proto), hopLimit: nil, &reader) : .other
                )
            case .v6:
                try reader.skip(5) // traffic class, flow label, payload length
                let nextHeader: UInt8 = try reader.read()
                let hopLimit: UInt8 = try reader.read()
                let source = try PackedIPAddress.v6(
                    hi: reader.readBigEndian(UInt64.self),
                    lo: reader.readBigEndian(UInt64.self)
                )
                let destination = try PackedIPAddress.v6(
                    hi: reader.readBigEndian(UInt64.self),
                    lo: reader.readBigEndian(UInt64.self)
                )
                return ParsedPacket(
                    source: source,
                    destination: destination,
                    payload: transportAfterExtensionHeaders(nextHeader, hopLimit: hopLimit, &reader)
                )
            case nil:
                return nil
            }
        }

        /// Follows the IPv6 extension header chain to the transport. A later fragment, a chain longer than any real
        /// packet's, or a chain cut short all read as `.other`.
        private static func transportAfterExtensionHeaders(
            _ firstHeader: UInt8,
            hopLimit: UInt8,
            _ reader: inout BinaryDecoder<Mapped>
        ) -> Payload {
            var nextHeader = firstHeader
            do {
                for _ in 0 ..< maximumExtensionHeaders {
                    guard let extensionHeader = IPv6ExtensionHeader(rawValue: nextHeader) else {
                        return transport(IPProtocol(rawValue: nextHeader), hopLimit: hopLimit, &reader)
                    }
                    switch extensionHeader {
                    case .hopByHop, .routing, .destinationOptions, .authentication:
                        let next: UInt8 = try reader.read()
                        let length: UInt8 = try reader.read()
                        try reader.skip(extensionHeader.totalLength(lengthField: length) - 2)
                        nextHeader = next
                    case .fragment:
                        let next: UInt8 = try reader.read()
                        try reader.skip(1) // reserved
                        let fragmentOffsetAndFlags = try reader.readBigEndian(UInt16.self)
                        try reader.skip(4) // identification
                        guard fragmentOffsetAndFlags & IPv6Header.fragmentOffsetMask == 0 else { return .other }
                        nextHeader = next
                    }
                }
            } catch {
                return .other
            }
            return .other
        }

        /// Classifies the transport header according to what we want to let through, most traffic gets labeled as
        /// `.other` while the rest gets sent along for additional validation before letting it through.
        private static func transport(
            _ proto: IPProtocol?,
            hopLimit: UInt8?,
            _ reader: inout BinaryDecoder<Mapped>
        ) -> Payload {
            do {
                switch proto {
                case .udp:
                    let sourcePort = try reader.readBigEndian(UInt16.self)
                    let destinationPort = try reader.readBigEndian(UInt16.self)
                    try reader.skip(UDPHeader.length - 4) // length, checksum
                    if DHCPv4.ports.contains(sourcePort), DHCPv4.ports.contains(destinationPort) {
                        try reader.skip(DHCPv4.magicCookieOffset)
                        return try reader.readBigEndian(UInt32.self) == DHCPv4.magicCookie ? .dhcpV4 : .other
                    }
                    if DHCPv6.ports.contains(sourcePort), DHCPv6.ports.contains(destinationPort) {
                        let messageType: UInt8 = try reader.read()
                        return DHCPv6.messageTypes.contains(messageType) ? .dhcpV6 : .other
                    }
                    return .other
                case .icmpV4:
                    let type: UInt8 = try reader.read()
                    guard ICMPv4Type(rawValue: type) == .destinationUnreachable else { return .other }
                    try reader.skip(ICMPErrorMessage.invokedPacketOffset - 1) // code, checksum, unused
                    return .pathError(invokedDestination: try? invokedDestination(&reader))
                case .icmpV6:
                    guard let type = try ICMPv6Type(rawValue: reader.read()) else { return .other }
                    if type.isNeighborDiscovery {
                        return .neighborDiscovery(hopLimit: hopLimit ?? 0)
                    }
                    guard type == .packetTooBig else { return .other }
                    try reader.skip(ICMPErrorMessage.invokedPacketOffset - 1) // code, checksum, MTU
                    return .pathError(invokedDestination: try? invokedDestination(&reader))
                case nil:
                    return .other
                }
            } catch {
                return .other
            }
        }

        /// The destination of the packet an ICMP error reports about.
        private static func invokedDestination(_ reader: inout BinaryDecoder<Mapped>) throws -> PackedIPAddress? {
            let versionAndHeaderLength: UInt8 = try reader.read()
            switch IPVersion(rawValue: versionAndHeaderLength >> 4) {
            case .v4:
                try reader.skip(IPv4Header.destinationOffset - 1)
                return try .v4(reader.readBigEndian(UInt32.self))
            case .v6:
                try reader.skip(IPv6Header.destinationOffset - 1)
                return try .v6(hi: reader.readBigEndian(UInt64.self), lo: reader.readBigEndian(UInt64.self))
            case nil:
                return nil
            }
        }
    }

    private extension BinaryDecoder where Storage == Mapped {
        mutating func readBigEndian<T: FixedWidthInteger & BitwiseCopyable>(_: T.Type) throws -> T {
            try T(bigEndian: read())
        }
    }
#endif
