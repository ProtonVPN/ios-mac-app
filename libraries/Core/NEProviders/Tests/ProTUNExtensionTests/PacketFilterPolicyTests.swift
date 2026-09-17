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
    import Darwin
    import Foundation
    import Network
    import NetworkExtension
    @testable import ProTUNExtension
    import Testing
    import VPNCoreTypes

    @Suite("Packet filter policy")
    struct PacketFilterPolicyTests {
        private let endpoint = IPv4Address("185.159.157.1")!
        private let endpointV6 = IPv6Address("2001:db8::10")!

        private var blocking: PacketFilterPolicy {
            .emptyPolicy(allowsLocalNetworks: false)
        }

        private var tunnelOnly: PacketFilterPolicy {
            PacketFilterPolicy(
                tunnelInterfaceIndex: Interface.tunnel,
                endpointsV4: [endpoint],
                endpointsV6: [endpointV6],
                allowsLocalNetworks: false
            )
        }

        @Test
        func matchesTheTunnelTransportByFarEnd() {
            #expect(verdict(tunnelOnly, .outbound, udpV4(from: "192.0.2.5", to: "185.159.157.1")) == .allow)
            #expect(verdict(tunnelOnly, .inbound, udpV4(from: "185.159.157.1", to: "192.0.2.5")) == .allow)
            #expect(verdict(tunnelOnly, .outbound, udpV4(from: "192.0.2.5", to: "8.8.8.8")) == .drop)
            #expect(verdict(tunnelOnly, .inbound, udpV4(from: "8.8.8.8", to: "192.0.2.5")) == .drop)
            // The near end matching an endpoint must not count.
            #expect(verdict(tunnelOnly, .outbound, udpV4(from: "185.159.157.1", to: "8.8.8.8")) == .drop)
        }

        @Test
        func matchesIPv6TunnelEndpoints() {
            let toEndpoint = udpV6(from: "2001:db8::2", to: "2001:db8::10")
            let elsewhere = udpV6(from: "2001:db8::2", to: "2001:db8::99")
            #expect(verdict(tunnelOnly, .outbound, toEndpoint) == .allow)
            #expect(verdict(tunnelOnly, .outbound, elsewhere) == .drop)
        }

        @Test
        func blocksOrdinaryTrafficWithoutEndpoints() {
            #expect(verdict(blocking, .outbound, udpV4(from: "192.0.2.5", to: "185.159.157.1")) == .drop)
            #expect(verdict(blocking, .outbound, udpV6(from: "2001:db8::2", to: "2001:db8::10")) == .drop)
        }

        @Test
        func allowsDHCPThatKeepsTheLinkAlive() {
            let discover = dhcpV4(from: "0.0.0.0", to: "255.255.255.255")
            let solicit = dhcpV6(from: "fe80::1", to: "ff02::1:2")
            for policy in [blocking, tunnelOnly] {
                #expect(verdict(policy, .outbound, discover) == .allow)
                #expect(verdict(policy, .outbound, solicit) == .allow)
            }
            // A reply may come from any server, including one on a public-addressed link.
            let offer = dhcpV4(from: "203.0.113.1", to: "203.0.113.20", sourcePort: 67, destinationPort: 68)
            #expect(verdict(blocking, .inbound, offer) == .allow)
            // A request only ever needs the link: the same bytes bound for a public address do not pass.
            let renewal = dhcpV4(from: "203.0.113.20", to: "203.0.113.1")
            #expect(verdict(blocking, .outbound, renewal) == .drop)
            // The ports alone prove nothing: without the cookie this is just UDP.
            let portsOnly = udpV4(from: "0.0.0.0", to: "255.255.255.255", sourcePort: 68, destinationPort: 67)
            #expect(verdict(blocking, .outbound, portsOnly) == .drop)
            // A later fragment carries no UDP header, whatever its bytes look like, so the same message fails.
            var laterFragment = discover
            laterFragment[7] = 1 // fragment offset 1
            #expect(verdict(blocking, .outbound, laterFragment) == .drop)
        }

        @Test
        func allowsNeighborDiscoveryWithTheRequiredHopLimit() {
            let solicitation = icmpV6(from: "fe80::1", to: "ff02::1:ff00:10", type: 135, hopLimit: 255)
            let forged = icmpV6(from: "fe80::1", to: "ff02::1:ff00:10", type: 135, hopLimit: 64)
            let echo = icmpV6(from: "fe80::1", to: "2001:db8::99", type: 128, hopLimit: 255)
            #expect(verdict(blocking, .outbound, solicitation) == .allow)
            #expect(verdict(blocking, .outbound, forged) == .drop)
            #expect(verdict(blocking, .outbound, echo) == .drop)
        }

        @Test
        func allowsInboundICMPErrorsAboutTheTunnelTransport() {
            let unreachable = icmpV4Unreachable(from: "203.0.113.1", to: "192.0.2.5", about: "185.159.157.1")
            let tooBig = icmpV6TooBig(from: "2001:db8:ffff::1", to: "2001:db8::2", about: "2001:db8::10")
            #expect(verdict(tunnelOnly, .inbound, unreachable) == .allow)
            #expect(verdict(tunnelOnly, .inbound, tooBig) == .allow)
            // Errors about anything else, errors we send, and echoes are ordinary traffic.
            let unrelated = icmpV4Unreachable(from: "203.0.113.1", to: "192.0.2.5", about: "8.8.8.8")
            #expect(verdict(tunnelOnly, .inbound, unrelated) == .drop)
            #expect(verdict(tunnelOnly, .outbound, unreachable) == .drop)
            let echo = icmpV4(from: "203.0.113.1", to: "192.0.2.5", type: 8)
            #expect(verdict(tunnelOnly, .inbound, echo) == .drop)
            // Without endpoints there is no transport to report about.
            #expect(verdict(blocking, .inbound, unreachable) == .drop)
            // An error cut short of the packet it reports on names no destination, so it proves nothing.
            #expect(verdict(tunnelOnly, .inbound, Array(unreachable.prefix(28))) == .drop)
        }

        @Test
        func localNetworksFollowTheLANPreference() {
            let toPrinter = udpV4(from: "192.168.1.5", to: "192.168.1.10", destinationPort: 631)
            var policy = blocking
            #expect(verdict(policy, .outbound, toPrinter) == .drop)
            policy.allowsLocalNetworks = true
            #expect(verdict(policy, .outbound, toPrinter) == .allow)
            // The far end decides: an inbound packet from a public source is not LAN traffic.
            let fromOutside = udpV4(from: "8.8.8.8", to: "192.168.1.5")
            #expect(verdict(policy, .inbound, fromOutside) == .drop)
            // IPv6 takes the same branch through its own packed ranges.
            let toLinkLocal = udpV6(from: "fe80::1", to: "fe80::2")
            #expect(verdict(policy, .outbound, toLinkLocal) == .allow)
        }

        @Test
        func dropsWhatItCannotParse() {
            let coordinator = PacketFilterCoordinator()
            coordinator.update(policy: tunnelOnly)
            let garbage: [UInt8] = [0x12, 0x34, 0x56]
            #expect(coordinator.verdict(direction: .outbound, packet: garbage) == .drop)
            #expect(coordinator.verdict(direction: .outbound, packet: []) == .drop)
            // An IPv4 header whose declared length exceeds the bytes is no header at all.
            let truncated: [UInt8] = [0x46, 0, 0, 24, 0, 0, 0, 0, 64, 17, 0, 0, 1, 2, 3, 4, 5, 6, 7, 8]
            #expect(coordinator.verdict(direction: .outbound, packet: truncated) == .drop)
            #expect(coordinator.drops == DroppedPacketCounts(blocked: 0, unparseable: 3))
            // A packet that parses but matches nothing is a different kind of drop.
            let wellFormed = udpV4(from: "10.0.0.2", to: "8.8.8.8")
            #expect(coordinator.verdict(direction: .outbound, packet: wellFormed) == .drop)
            #expect(coordinator.drops == DroppedPacketCounts(blocked: 1, unparseable: 3))
        }

        @Test
        func walksIPv6ExtensionHeadersToTheTransport() {
            // A DHCPv6 solicit passes under a blocking policy only if the parser reaches the UDP header behind the
            // extension chain, since nothing about its addresses justifies it.
            let solicit = udpHeader(sourcePort: 546, destinationPort: 547) + [1, 0, 0, 1]
            let behindHopByHop = ipV6Header(from: "fe80::1", to: "ff02::1:2", nextHeader: 0)
                + [17, 0, 0, 0, 0, 0, 0, 0] // hop-by-hop: next = UDP, length 0 (8 bytes)
                + solicit
            #expect(verdict(blocking, .outbound, behindHopByHop) == .allow)
            // A first fragment still carries the transport header.
            let firstFragment = ipV6Header(from: "fe80::1", to: "ff02::1:2", nextHeader: 44)
                + [17, 0, 0, 1, 0, 0, 0, 1] // fragment: next = UDP, offset 0 with more to come
                + solicit
            #expect(verdict(blocking, .outbound, firstFragment) == .allow)
            // A later fragment does not, whatever its bytes look like, so the exception cannot apply.
            let laterFragment = ipV6Header(from: "fe80::1", to: "ff02::1:2", nextHeader: 44)
                + [17, 0, 0, 8, 0, 0, 0, 1] // fragment: next = UDP, offset 1
                + solicit
            #expect(verdict(blocking, .outbound, laterFragment) == .drop)
            // The authentication header counts 4-byte units past its first two, unlike the 8-byte units of the other
            // extension headers.
            let behindAuthentication = ipV6Header(from: "fe80::1", to: "ff02::1:2", nextHeader: 51)
                + [17, 4] + [UInt8](repeating: 0, count: 22) // authentication: next = UDP, length 4 (24 bytes)
                + solicit
            #expect(verdict(blocking, .outbound, behindAuthentication) == .allow)
        }

        @Test
        func classifiesLocalRanges() throws {
            #expect(try packed("10.1.2.3").isLocalNetwork)
            #expect(try packed("172.31.0.1").isLocalNetwork)
            #expect(try !packed("172.32.0.1").isLocalNetwork)
            #expect(try packed("169.254.10.1").isLocalNetwork)
            #expect(try packed("224.0.0.251").isLocalNetwork)
            #expect(try packed("255.255.255.255").isLocalNetwork)
            #expect(try !packed("185.159.157.1").isLocalNetwork)
            #expect(try packed("fe80::1").isLocalNetwork)
            #expect(try packed("fc00::1").isLocalNetwork)
            #expect(try packed("ff02::1").isLocalNetwork)
            #expect(try !packed("2001:db8::1").isLocalNetwork)
        }

        @Test
        func derivesThePolicyFromTheTunnelConfiguration() {
            let peer = ProTUNConfiguration.Peer(
                id: "peer",
                serverIP: "185.159.157.1",
                serverPublicKey: "key",
                udpPorts: [51820],
                tcpPorts: [],
                tlsPorts: [],
                priority: 0,
                exitLabel: nil
            )
            let connected = PacketFilterPolicy(
                configuration: .init(preferredTransport: .udp, peers: [peer], dnsServers: []),
                tunnelInterfaceIndex: Interface.tunnel,
                allowsLocalNetworks: true
            )
            #expect(connected.tunnelInterfaceIndex == Interface.tunnel)
            #expect(connected.endpointsV4 == [endpoint])
            #expect(connected.endpointsV6.isEmpty)
            #expect(connected.allowsLocalNetworks)

            let blackhole = PacketFilterPolicy(
                configuration: .init(preferredTransport: .udp, peers: [], dnsServers: []),
                tunnelInterfaceIndex: Interface.tunnel,
                allowsLocalNetworks: false
            )
            // No peers: the policy allows no transport endpoint, so only the always-allowed classes pass.
            #expect(blackhole.tunnelInterfaceIndex == Interface.tunnel)
            #expect(blackhole.endpointsV4.isEmpty)
            #expect(blackhole.endpointsV6.isEmpty)
        }

        // MARK: - Property tests

        /// The packet path classifies addresses on packed integers. Those answers must agree with the Network
        /// framework's own range predicates, which stand in as the reference, across addresses drawn to sit on and
        /// around every range boundary.
        @Test
        func packedLocalNetworkClassificationMatchesTheFramework() {
            var rng = SplitMix64(seed: 0x5EED_0001)
            for _ in 0 ..< 20000 {
                let value = rng.interestingIPv4()
                let bytes = withUnsafeBytes(of: value.bigEndian) { [UInt8]($0) }
                let expected = isLocalAccordingToFoundation(bytes[...])
                #expect(PackedIPAddress.v4(value).isLocalNetwork == expected, "\(hex(bytes))")
            }
            for _ in 0 ..< 20000 {
                let (hi, lo) = rng.interestingIPv6()
                let bytes = withUnsafeBytes(of: hi.bigEndian) { [UInt8]($0) }
                    + withUnsafeBytes(of: lo.bigEndian) { [UInt8]($0) }
                let expected = isLocalAccordingToFoundation(bytes[...])
                #expect(PackedIPAddress.v6(hi: hi, lo: lo).isLocalNetwork == expected, "\(hex(bytes))")
            }
        }

        /// Runs cut-short, byte-flipped, and fully random packets through the verdict and checks two properties: the
        /// parser never traps, and every `.allow` on a non-tunnel interface is one that ``couldBeAllowed`` can justify
        /// from its own reading of the bytes. A disagreement points at a parser offset or length mistake.
        @Test
        func verdictNeverTrapsAndOnlyAllowsJustifiedPackets() {
            var rng = SplitMix64(seed: 0x5EED_0002)
            var lanAllowed = tunnelOnly
            lanAllowed.allowsLocalNetworks = true
            let policies = [blocking, tunnelOnly, lanAllowed].map { policy in
                let coordinator = PacketFilterCoordinator()
                coordinator.update(policy: policy)
                return (policy, coordinator)
            }
            let directions: [NETrafficDirection] = [.outbound, .inbound, .any]

            func check(_ packet: [UInt8], origin: String) {
                for (policy, coordinator) in policies {
                    for direction in directions {
                        let outcome = coordinator.verdict(direction: direction, packet: packet)
                        guard outcome == .allow else { continue }
                        #expect(
                            couldBeAllowed(packet, direction: direction, policy: policy),
                            "unjustified allow (\(origin), direction \(direction.rawValue)): \(hex(packet))"
                        )
                    }
                }
            }

            for (name, seed) in seedPackets() {
                for length in 0 ... seed.count {
                    check(Array(seed.prefix(length)), origin: "\(name) cut to \(length) bytes")
                }
                for _ in 0 ..< 1000 {
                    var packet = seed
                    for _ in 0 ... Int.random(in: 0 ..< 3, using: &rng) {
                        let index = Int.random(in: 0 ..< min(72, packet.count), using: &rng)
                        packet[index] ^= UInt8.random(in: 1 ... 255, using: &rng)
                    }
                    check(packet, origin: "\(name) mutated")
                }
            }
            for _ in 0 ..< 2000 {
                let count = Int.random(in: 0 ..< 128, using: &rng)
                check((0 ..< count).map { _ in UInt8.random(in: 0 ... 255, using: &rng) }, origin: "random")
            }
        }

        /// Well-formed packets carrying ordinary transports are judged by their far end alone, whatever length of IPv4
        /// options or IPv6 extension chain sits in front of the transport. Every verdict here is predictable, so a
        /// parser that skipped the wrong number of bytes, and so read the addresses or the transport from the wrong
        /// place, disagrees with the expectation.
        @Test
        func wellFormedPacketsAreJudgedByTheirFarEnd() throws {
            var rng = SplitMix64(seed: 0x5EED_0003)
            for _ in 0 ..< 10000 {
                let size = Bool.random(using: &rng) ? 4 : 16
                let source = randomBytes(size, using: &rng)
                let destination = randomBytes(size, using: &rng)
                let endpoint = switch Int.random(in: 0 ..< 4, using: &rng) {
                case 0, 1: destination
                case 2: source
                default: randomBytes(size, using: &rng)
                }
                let lookup = try PacketFilterPolicy.Lookup(policy(endpoint: endpoint))
                let bytes = randomOrdinaryPacket(from: source, to: destination, using: &rng)
                let packet = try #require(parsed(bytes))
                let expectations: [(NETrafficDirection, Bool)] = [
                    (.outbound, destination == endpoint),
                    (.inbound, source == endpoint),
                    (.any, source == endpoint || destination == endpoint),
                ]
                for (direction, allowed) in expectations {
                    #expect(
                        lookup.allows(packet, direction: direction) == allowed,
                        "direction \(direction.rawValue), endpoint \(hex(endpoint)): \(hex(bytes))"
                    )
                }
            }
        }

        /// A blocking policy that allows exactly one endpoint.
        private func policy(endpoint: [UInt8]) throws -> PacketFilterPolicy {
            var policy = blocking
            if endpoint.count == 4 {
                policy.endpointsV4 = try [#require(IPv4Address(Data(endpoint)))]
            } else {
                policy.endpointsV6 = try [#require(IPv6Address(Data(endpoint)))]
            }
            return policy
        }

        /// A well-formed packet from `source` to `destination` carrying TCP or UDP on ports the policy has no special
        /// case for. IPv4 packets get a random number of option words and are sometimes a later fragment. IPv6 packets
        /// get a random extension chain, possibly including a fragment header, before the transport.
        private func randomOrdinaryPacket(
            from source: [UInt8],
            to destination: [UInt8],
            using rng: inout SplitMix64
        ) -> [UInt8] {
            let proto: UInt8 = Bool.random(using: &rng) ? 6 : 17
            let transport: [UInt8] = if proto == 17 {
                udpHeader(
                    sourcePort: UInt16.random(in: 1024 ... 65535, using: &rng),
                    destinationPort: UInt16.random(in: 1024 ... 65535, using: &rng)
                )
            } else {
                randomBytes(20, using: &rng)
            }
            let payload = randomBytes(Int.random(in: 0 ..< 16, using: &rng), using: &rng)

            if source.count == 4 {
                let optionWords = Int.random(in: 0 ... 10, using: &rng)
                let fragmentOffset = Bool.random(using: &rng) ? 0 : UInt16.random(in: 1 ... 0x1FFF, using: &rng)
                var packet: [UInt8] = [0x40 | UInt8(5 + optionWords), 0, 0, 0, 0, 0]
                packet += [UInt8(fragmentOffset >> 8), UInt8(fragmentOffset & 0xFF), 64, proto, 0, 0]
                packet += source + destination + randomBytes(optionWords * 4, using: &rng)
                return packet + transport + payload
            }

            // Build the chain from the transport outwards, so each header's next-header byte names what follows it.
            var chain: [UInt8] = []
            var nextHeader = proto
            for _ in 0 ..< Int.random(in: 0 ... 4, using: &rng) {
                let kinds: [UInt8] = [0, 43, 51, 60, 44]
                let kind = kinds[Int.random(in: 0 ..< kinds.count, using: &rng)]
                let header: [UInt8]
                switch kind {
                case 44:
                    let laterFragment = UInt16.random(in: 8 ... 0xFFF8, using: &rng) & 0xFFF8
                    let offsetAndFlags = Bool.random(using: &rng) ? 0 : laterFragment
                    header = [nextHeader, 0, UInt8(offsetAndFlags >> 8), UInt8(offsetAndFlags & 0xFF)]
                        + randomBytes(4, using: &rng)
                case 51:
                    let length = UInt8.random(in: 0 ... 3, using: &rng)
                    header = [nextHeader, length] + randomBytes((Int(length) + 2) * 4 - 2, using: &rng)
                default:
                    let length = UInt8.random(in: 0 ... 3, using: &rng)
                    header = [nextHeader, length] + randomBytes((Int(length) + 1) * 8 - 2, using: &rng)
                }
                chain = header + chain
                nextHeader = kind
            }
            let packet: [UInt8] = [0x60, 0, 0, 0, 0, 0, nextHeader, 64] + source + destination
            return packet + chain + transport + payload
        }

        private func randomBytes(_ count: Int, using rng: inout SplitMix64) -> [UInt8] {
            (0 ..< count).map { _ in UInt8.random(in: 0 ... 255, using: &rng) }
        }

        /// Well-formed packets of every kind the policy distinguishes, as starting points for mutation.
        private func seedPackets() -> [(String, [UInt8])] {
            let extensionChain = ipV6Header(from: "2001:db8::2", to: "2001:db8::10", nextHeader: 0)
                + [60, 0, 0, 0, 0, 0, 0, 0] // hop-by-hop: next = destination options, 8 bytes
                + [51, 1] + [UInt8](repeating: 0, count: 14) // destination options: next = authentication, 16 bytes
                + [44, 4] + [UInt8](repeating: 0, count: 22) // authentication: next = fragment, 24 bytes
                + [17, 0, 0, 0, 0, 0, 0, 1] // fragment: next = UDP, first fragment
                + udpHeader(sourcePort: 40000, destinationPort: 51820)
            return [
                ("udpV4", udpV4(from: "10.0.0.2", to: "185.159.157.1", destinationPort: 51820)),
                ("udpV4 reply", udpV4(from: "185.159.157.1", to: "10.0.0.2", sourcePort: 51820)),
                ("udpV4 LAN", udpV4(from: "192.168.1.5", to: "192.168.1.10", destinationPort: 631)),
                ("dhcpV4", dhcpV4(from: "0.0.0.0", to: "255.255.255.255")),
                ("icmpV4 unreachable", icmpV4Unreachable(from: "1.2.3.4", to: "10.0.0.2", about: "185.159.157.1")),
                ("udpV6", udpV6(from: "2001:db8::2", to: "2001:db8::10", destinationPort: 51820)),
                ("udpV6 reply", udpV6(from: "2001:db8::10", to: "2001:db8::2", sourcePort: 51820)),
                ("dhcpV6", dhcpV6(from: "fe80::1", to: "ff02::1:2")),
                ("neighbor solicitation", icmpV6(from: "fe80::1", to: "ff02::1", type: 135, hopLimit: 255)),
                ("icmpV6 too big", icmpV6TooBig(from: "2001:db8::1", to: "2001:db8::2", about: "2001:db8::10")),
                ("extension chain", extensionChain),
            ]
        }

        /// An independent reading of a packet that says whether an `.allow` could be justified. It compares the far end
        /// against the policy at the fixed header offsets, walks the IPv6 extension chain with its own loop, and treats
        /// every transport the policy sanctions as allowable without checking its finer conditions. It therefore
        /// accepts a superset of what the real parser allows, and anything outside it is a bug.
        private func couldBeAllowed(
            _ packet: [UInt8],
            direction: NETrafficDirection,
            policy: PacketFilterPolicy
        ) -> Bool {
            guard let first = packet.first else { return false }
            let farEnds: [ArraySlice<UInt8>]
            let endpoints: [[UInt8]]
            let transport: (proto: UInt8, offset: Int)?
            switch first >> 4 {
            case 4:
                guard packet.count >= 20 else { return false }
                farEnds = ends(source: packet[12 ..< 16], destination: packet[16 ..< 20], direction)
                endpoints = policy.endpointsV4.map { [UInt8]($0.rawValue) }
                transport = (packet[9], Int(first & 0x0F) * 4)
            case 6:
                guard packet.count >= 40 else { return false }
                farEnds = ends(source: packet[8 ..< 24], destination: packet[24 ..< 40], direction)
                endpoints = policy.endpointsV6.map { [UInt8]($0.rawValue) }
                transport = transportAfterExtensionHeaders(packet)
            default:
                return false
            }
            if farEnds.contains(where: { end in endpoints.contains { $0.elementsEqual(end) } }) {
                return true
            }
            if policy.allowsLocalNetworks, farEnds.contains(where: isLocalAccordingToFoundation) {
                return true
            }
            guard let transport else { return false }
            switch transport.proto {
            case 1, 58: // ICMPv4, ICMPv6
                return true
            case 17: // UDP, allowable only on the DHCP ports
                guard packet.count >= transport.offset + 4 else { return false }
                let sourcePort = UInt16(packet[transport.offset]) << 8 | UInt16(packet[transport.offset + 1])
                let destinationPort = UInt16(packet[transport.offset + 2]) << 8 | UInt16(packet[transport.offset + 3])
                let dhcp: [ClosedRange<UInt16>] = [67 ... 68, 546 ... 547]
                return dhcp.contains { $0.contains(sourcePort) && $0.contains(destinationPort) }
            default:
                return false
            }
        }

        /// The oracle's own walk of the IPv6 extension chain to the transport. Returns nil for a chain the packet cuts
        /// short, a later fragment, or a chain longer than the parser follows, in which case only an address match can
        /// justify an allow.
        private func transportAfterExtensionHeaders(_ packet: [UInt8]) -> (proto: UInt8, offset: Int)? {
            var next = packet[6]
            var offset = 40
            for _ in 0 ..< 8 {
                switch next {
                case 0, 43, 51, 60: // hop-by-hop, routing, authentication, destination options
                    guard packet.count >= offset + 2 else { return nil }
                    let length = Int(packet[offset + 1])
                    let headerLength = next == 51 ? (length + 2) * 4 : (length + 1) * 8
                    next = packet[offset]
                    offset += headerLength
                case 44: // fragment
                    guard packet.count >= offset + 8 else { return nil }
                    let offsetAndFlags = UInt16(packet[offset + 2]) << 8 | UInt16(packet[offset + 3])
                    guard offsetAndFlags & 0xFFF8 == 0 else { return nil }
                    next = packet[offset]
                    offset += 8
                default:
                    return (next, offset)
                }
            }
            return nil
        }

        private func ends(
            source: ArraySlice<UInt8>,
            destination: ArraySlice<UInt8>,
            _ direction: NETrafficDirection
        ) -> [ArraySlice<UInt8>] {
            switch direction {
            case .outbound: [destination]
            case .inbound: [source]
            default: [source, destination]
            }
        }

        /// The reference classification, built from the Network framework's predicates plus the RFC 1918 and limited
        /// broadcast ranges it has no predicate for.
        private func isLocalAccordingToFoundation(_ bytes: ArraySlice<UInt8>) -> Bool {
            if bytes.count == 4, let address = IPv4Address(Data(bytes)) {
                let value = bytes.reduce(UInt32(0)) { $0 << 8 | UInt32($1) }
                let privateUse = value >> 24 == 10 || value >> 20 == 0xAC1 || value >> 16 == 0xC0A8
                return address.isLinkLocal || address.isMulticast || privateUse || value == .max
            }
            if bytes.count == 16, let address = IPv6Address(Data(bytes)) {
                return address.isLinkLocal || address.isUniqueLocal || address.isMulticast
            }
            return false
        }

        private func packed(_ string: String) throws -> PackedIPAddress {
            if let v4 = IPv4Address(string) {
                return PackedIPAddress(v4)
            }
            return try PackedIPAddress(#require(IPv6Address(string)))
        }

        private func hex(_ bytes: [UInt8]) -> String {
            bytes.map { String(format: "%02x", $0) }.joined()
        }

        /// Runs one packet through a coordinator that enforces `policy`, on the given interface.
        private func verdict(
            _ policy: PacketFilterPolicy,
            on interfaceIndex: UInt32 = Interface.other,
            type interfaceType: nw_interface_type_t = nw_interface_type_other,
            _ direction: NETrafficDirection,
            _ packet: [UInt8]
        ) -> NEFilterPacketProvider.Verdict {
            let coordinator = PacketFilterCoordinator()
            coordinator.update(policy: policy)
            return coordinator.verdict(on: interfaceIndex, type: interfaceType, direction: direction, packet: packet)
        }

        private func parsed(_ packet: [UInt8]) -> ParsedPacket? {
            packet.withUnsafeBytes { ParsedPacket($0.bytes) }
        }

        private func udpV4(
            from source: String,
            to destination: String,
            sourcePort: UInt16 = 40000,
            destinationPort: UInt16 = 443,
            payload: [UInt8] = []
        ) -> [UInt8] {
            ipV4Header(from: source, to: destination, proto: 17)
                + udpHeader(sourcePort: sourcePort, destinationPort: destinationPort)
                + payload
        }

        private func udpV6(
            from source: String,
            to destination: String,
            sourcePort: UInt16 = 40000,
            destinationPort: UInt16 = 443,
            payload: [UInt8] = []
        ) -> [UInt8] {
            ipV6Header(from: source, to: destination, nextHeader: 17)
                + udpHeader(sourcePort: sourcePort, destinationPort: destinationPort)
                + payload
        }

        /// A DHCPv4 message: the fixed BOOTP fields, then the magic cookie.
        private func dhcpV4(
            from source: String,
            to destination: String,
            sourcePort: UInt16 = 68,
            destinationPort: UInt16 = 67
        ) -> [UInt8] {
            let bootp = [UInt8](repeating: 0, count: 236) + [0x63, 0x82, 0x53, 0x63]
            return udpV4(
                from: source,
                to: destination,
                sourcePort: sourcePort,
                destinationPort: destinationPort,
                payload: bootp
            )
        }

        /// A DHCPv6 SOLICIT: message type 1 and a transaction id.
        private func dhcpV6(from source: String, to destination: String) -> [UInt8] {
            udpV6(from: source, to: destination, sourcePort: 546, destinationPort: 547, payload: [1, 0, 0, 1])
        }

        private func icmpV4(from source: String, to destination: String, type: UInt8) -> [UInt8] {
            ipV4Header(from: source, to: destination, proto: 1) + [type, 0, 0, 0]
        }

        /// A destination unreachable error carrying the header of a UDP packet that was bound for `about`.
        private func icmpV4Unreachable(from source: String, to destination: String, about: String) -> [UInt8] {
            ipV4Header(from: source, to: destination, proto: 1)
                + [3, 4, 0, 0, 0, 0, 0, 0] // fragmentation needed, checksum, unused
                + udpV4(from: destination, to: about, destinationPort: 51820)
        }

        private func icmpV6(from source: String, to destination: String, type: UInt8, hopLimit: UInt8 = 64) -> [UInt8] {
            ipV6Header(from: source, to: destination, nextHeader: 58, hopLimit: hopLimit) + [type, 0, 0, 0]
        }

        /// A packet too big error carrying the header of a UDP packet that was bound for `about`.
        private func icmpV6TooBig(from source: String, to destination: String, about: String) -> [UInt8] {
            ipV6Header(from: source, to: destination, nextHeader: 58)
                + [2, 0, 0, 0, 0, 0, 0x05, 0xDC] // code, checksum, MTU 1500
                + udpV6(from: destination, to: about, destinationPort: 51820)
        }

        private func ipV4Header(from source: String, to destination: String, proto: UInt8) -> [UInt8] {
            var packet: [UInt8] = [0x45, 0, 0, 28, 0, 0, 0, 0, 64, proto, 0, 0]
            packet += address(source, family: AF_INET, size: 4)
            packet += address(destination, family: AF_INET, size: 4)
            return packet
        }

        private func ipV6Header(
            from source: String,
            to destination: String,
            nextHeader: UInt8,
            hopLimit: UInt8 = 64
        ) -> [UInt8] {
            var packet: [UInt8] = [0x60, 0, 0, 0, 0, 8, nextHeader, hopLimit]
            packet += address(source, family: AF_INET6, size: 16)
            packet += address(destination, family: AF_INET6, size: 16)
            return packet
        }

        private func udpHeader(sourcePort: UInt16, destinationPort: UInt16) -> [UInt8] {
            [
                UInt8(sourcePort >> 8), UInt8(sourcePort & 0xFF),
                UInt8(destinationPort >> 8), UInt8(destinationPort & 0xFF),
                0, 8, 0, 0,
            ]
        }

        private func address(_ string: String, family: Int32, size: Int) -> [UInt8] {
            var bytes = [UInt8](repeating: 0, count: size)
            precondition(inet_pton(family, string, &bytes) == 1)
            return bytes
        }
    }

    /// A small deterministic generator, so a failing case reproduces from the seed named in the test.
    private struct SplitMix64: RandomNumberGenerator {
        private var state: UInt64

        init(seed: UInt64) {
            self.state = seed
        }

        mutating func next() -> UInt64 {
            state &+= 0x9E37_79B9_7F4A_7C15
            var z = state
            z = (z ^ (z >> 30)) &* 0xBF58_476D_1CE4_E5B9
            z = (z ^ (z >> 27)) &* 0x94D0_49BB_1331_11EB
            return z ^ (z >> 31)
        }

        /// The first address of each local range and of the range right after it.
        private static let ipv4Boundaries: [UInt32] = [
            0x0A00_0000, 0x0B00_0000, // 10.0.0.0/8
            0xAC10_0000, 0xAC20_0000, // 172.16.0.0/12
            0xC0A8_0000, 0xC0A9_0000, // 192.168.0.0/16
            0xA9FE_0000, 0xA9FF_0000, // 169.254.0.0/16
            0xE000_0000, 0xF000_0000, // 224.0.0.0/4
            0xFFFF_FFFF, // 255.255.255.255
        ]

        /// The leading 16 bits of each local IPv6 range, plus neighbors just outside it and some public space.
        private static let ipv6Prefixes: [UInt64] = [
            0xFE80, 0xFEBF, 0xFEC0, 0xFE7F, // fe80::/10 and either side of it
            0xFC00, 0xFDFF, 0xFBFF, 0xFE00, // fc00::/7 and either side of it
            0xFF00, 0xFF02, 0xFFFF, // ff00::/8
            0x2001, 0x0000,
        ]

        /// Half the addresses are uniform, half sit within a few thousand of a range boundary, where a mask mistake
        /// would show.
        mutating func interestingIPv4() -> UInt32 {
            guard Bool.random(using: &self) else { return UInt32.random(in: .min ... .max, using: &self) }
            let boundary = Self.ipv4Boundaries[Int.random(in: 0 ..< Self.ipv4Boundaries.count, using: &self)]
            return boundary &+ UInt32(truncatingIfNeeded: Int.random(in: -0x1000 ..< 0x1000, using: &self))
        }

        /// Half the addresses are uniform, half start with one of the prefixes that matter.
        mutating func interestingIPv6() -> (hi: UInt64, lo: UInt64) {
            let lo = next()
            guard Bool.random(using: &self) else { return (next(), lo) }
            let prefix = Self.ipv6Prefixes[Int.random(in: 0 ..< Self.ipv6Prefixes.count, using: &self)]
            return (prefix << 48 | next() >> 16, lo)
        }
    }

    @Suite("Packet filter coordinator")
    struct PacketFilterCoordinatorTests {
        @Test
        func startsFailClosedAndExemptsLoopbackAndTheTunnel() {
            let coordinator = PacketFilterCoordinator()
            let packet: [UInt8] = [
                0x45, 0, 0, 28, 0, 0, 0, 0, 64, 17, 0, 0,
                8, 8, 8, 8, 192, 0, 2, 5,
                0x9C, 0x40, 0x01, 0xBB, 0, 8, 0, 0,
            ]
            #expect(coordinator.verdict(direction: .inbound, packet: packet) == .drop)
            #expect(coordinator.verdict(type: .loopback, direction: .inbound, packet: packet) == .allow)

            coordinator.update(policy: PacketFilterPolicy(
                tunnelInterfaceIndex: Interface.tunnel,
                endpointsV4: [],
                endpointsV6: [],
                allowsLocalNetworks: false
            ))
            // Only the interface whose index the policy holds is the tunnel. Loopback stays exempt under every policy.
            #expect(coordinator.verdict(on: Interface.tunnel, direction: .inbound, packet: packet) == .allow)
            #expect(coordinator.verdict(on: Interface.otherTunnel, direction: .inbound, packet: packet) == .drop)
            #expect(coordinator.verdict(type: .loopback, direction: .inbound, packet: packet) == .allow)
        }

        @Test
        func countsDropsUntilTheyAreReported() {
            let coordinator = PacketFilterCoordinator()
            let blocked: [UInt8] = [
                0x45, 0, 0, 28, 0, 0, 0, 0, 64, 17, 0, 0,
                8, 8, 8, 8, 192, 0, 2, 5,
                0x9C, 0x40, 0x01, 0xBB, 0, 8, 0, 0,
            ]
            let garbage: [UInt8] = [0x12, 0x34, 0x56]
            let longGarbage = [UInt8](repeating: 0x12, count: 100)
            let send = { (bytes: [UInt8]) in
                coordinator.verdict(direction: .inbound, packet: bytes)
            }

            #expect(coordinator.drops == DroppedPacketCounts())
            #expect(send(blocked) == .drop)
            #expect(send(blocked) == .drop)
            // The first unparseable packet is the one the log shows, cut to its leading bytes.
            #expect(send(longGarbage) == .drop)
            #expect(send(garbage) == .drop)
            // Allowed packets never count.
            #expect(coordinator.verdict(type: .loopback, direction: .inbound, packet: garbage) == .allow)
            #expect(coordinator.drops.blocked == 2)
            #expect(coordinator.drops.unparseable == 2)

            // A policy change resets the counts. The same policy again does not.
            coordinator.update(policy: .emptyPolicy(allowsLocalNetworks: true))
            #expect(coordinator.drops == DroppedPacketCounts())
            #expect(send(garbage) == .drop)
            coordinator.update(policy: .emptyPolicy(allowsLocalNetworks: true))
            #expect(coordinator.drops.unparseable == 1)

            // Stopping the filter resets them too.
            coordinator.filterDidStop()
            #expect(coordinator.drops == DroppedPacketCounts())
        }

        @Test
        func tracksWhetherAFilterProviderIsRunning() {
            let coordinator = PacketFilterCoordinator()
            #expect(!coordinator.isFilterActive)
            coordinator.filterDidStart()
            #expect(coordinator.isFilterActive)
            coordinator.filterDidStop()
            #expect(!coordinator.isFilterActive)
        }
    }

    /// Interface indices the tests use in place of real interfaces.
    private enum Interface {
        static let other: UInt32 = 3
        static let tunnel: UInt32 = 7
        static let otherTunnel: UInt32 = 8
    }

    private extension PacketFilterCoordinator {
        /// Checks a single packet and decides whether or not to allow it.
        func verdict(
            on interfaceIndex: UInt32 = Interface.other,
            type interfaceType: nw_interface_type_t = nw_interface_type_other,
            direction: NETrafficDirection,
            packet: [UInt8]
        ) -> NEFilterPacketProvider.Verdict {
            packet.withUnsafeBytes { raw in
                verdict(
                    interfaceIndex: interfaceIndex,
                    interfaceType: interfaceType,
                    direction: direction,
                    packet: raw.bytes
                )
            }
        }
    }

    private extension nw_interface_type_t {
        static let loopback = nw_interface_type_loopback
    }
#endif
