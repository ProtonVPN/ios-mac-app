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

import Ergonomics
import Testing

@Suite("IP constants")
struct IPConstantsTests {
    @Test
    func privateUseBlocksCoverRFC1918AndNothingElse() {
        func isPrivate(_ address: UInt32) -> Bool {
            IPv4Block.privateUse.contains { $0.contains(address) }
        }
        #expect(isPrivate(0x0A00_0001)) // 10.0.0.1
        #expect(isPrivate(0xAC1F_FFFF)) // 172.31.255.255
        #expect(!isPrivate(0xAC20_0000)) // 172.32.0.0
        #expect(isPrivate(0xC0A8_0001)) // 192.168.0.1
        #expect(!isPrivate(0xB99F_9D01)) // 185.159.157.1
    }

    @Test
    func blocksContainTheirWholePrefixAndNoMore() {
        let block = IPv4Block(network: 0xC0A8_0000, prefixLength: 16)
        #expect(block.contains(0xC0A8_0000))
        #expect(block.contains(0xC0A8_FFFF))
        #expect(!block.contains(0xC0A9_0000))
        #expect(IPv4Block(network: 0, prefixLength: 0).contains(0xFFFF_FFFF))
        #expect(IPv4Block(network: 0x0A00_0001, prefixLength: 32).contains(0x0A00_0001))
        #expect(!IPv4Block(network: 0x0A00_0001, prefixLength: 32).contains(0x0A00_0002))
    }

    @Test
    func blocksContainSubnetsButNotSupernetsOrNeighbors() {
        let privateTen = IPv4Block(network: 0x0A00_0000, prefixLength: 8)
        #expect(privateTen.contains(IPv4Block(network: 0x0A00_0100, prefixLength: 24))) // 10.0.1.0/24
        #expect(privateTen.contains(privateTen))
        #expect(!privateTen.contains(IPv4Block(network: 0x0A00_0000, prefixLength: 7))) // 10.0.0.0/7 spills into 11/8
        #expect(!privateTen.contains(IPv4Block(network: 0x0B00_0000, prefixLength: 24))) // 11.0.0.0/24
    }

    @Test
    func localNetworkBlocksCoverTheLinkAndNothingPublic() {
        func isLocal(_ address: UInt32) -> Bool {
            IPv4Block.localNetworks.contains { $0.contains(address) }
        }
        #expect(isLocal(0x0A01_0203)) // 10.1.2.3
        #expect(isLocal(0xA9FE_0A01)) // 169.254.10.1
        #expect(!isLocal(0xA9FF_0000)) // 169.255.0.0
        #expect(isLocal(0xE000_00FB)) // 224.0.0.251
        #expect(isLocal(0xEFFF_FFFF)) // 239.255.255.255
        #expect(!isLocal(0xF000_0000)) // 240.0.0.0
        #expect(isLocal(0xFFFF_FFFF)) // 255.255.255.255
        #expect(!isLocal(0xFFFF_FFFE)) // 255.255.255.254
        #expect(!isLocal(0xB99F_9D01)) // 185.159.157.1
    }

    @Test
    func ipv6BlocksMatchOnTheHighBitsOnly() {
        func isLocal(_ high: UInt64) -> Bool {
            IPv6Block.localNetworks.contains { $0.contains(high: high) }
        }
        #expect(isLocal(0xFE80_0000_0000_0000)) // fe80::
        #expect(isLocal(0xFEBF_FFFF_FFFF_FFFF)) // the last /64 in fe80::/10
        #expect(!isLocal(0xFEC0_0000_0000_0000)) // fec0::, just past it
        #expect(isLocal(0xFC00_0000_0000_0000)) // fc00::
        #expect(isLocal(0xFDFF_0000_0000_0000)) // fdff::, still in fc00::/7
        #expect(!isLocal(0xFBFF_0000_0000_0000)) // fbff::
        #expect(isLocal(0xFF02_0000_0000_0000)) // ff02::
        #expect(!isLocal(0x2001_0DB8_0000_0000)) // 2001:db8::
        #expect(IPv6Block(network: 0, prefixLength: 0).contains(high: .max))
    }

    @Test
    func extensionHeaderLengthsFollowTheirUnits() {
        #expect(IPv6ExtensionHeader.hopByHop.totalLength(lengthField: 0) == 8)
        #expect(IPv6ExtensionHeader.routing.totalLength(lengthField: 2) == 24)
        #expect(IPv6ExtensionHeader.authentication.totalLength(lengthField: 4) == 24)
        #expect(IPv6ExtensionHeader.fragment.totalLength(lengthField: 9) == 8)
    }

    @Test
    func neighborDiscoveryIsExactlyTheRFC4861Set() {
        for raw in UInt8(133) ... 137 {
            #expect(ICMPv6Type(rawValue: raw)?.isNeighborDiscovery == true)
        }
        #expect(!ICMPv6Type.packetTooBig.isNeighborDiscovery)
    }
}
