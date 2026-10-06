//
//  Created on 05/10/2026.
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

import Network
import NetworkingErgonomics
import protun
@testable import ProTUNExtension
import Testing

@Suite("Connectivity events")
struct ConnectivityEventTests {
    private let cellular = NetworkPath(
        status: .satisfied,
        interfaceName: "pdp_ip0",
        interfaceIndex: 2,
        interfaceType: .cellular,
        gateways: [],
        supportsIPv4: true,
        supportsIPv6: false
    )

    private let wifi = NetworkPath(
        status: .satisfied,
        interfaceName: "en0",
        interfaceIndex: 23,
        interfaceType: .wifi,
        gateways: ["192.168.1.1:0"],
        supportsIPv4: true,
        supportsIPv6: true
    )

    @Test
    func reportsThePhysicalNetworkComingChangingAndGoing() {
        #expect(NetworkPath.eventFromUpdates(old: .initial, new: cellular) == .up)
        #expect(NetworkPath.eventFromUpdates(old: cellular, new: wifi) == .networkSwitch)
        #expect(NetworkPath.eventFromUpdates(old: wifi, new: .initial) == .down)
    }

    /// A usable path with no physical interface gives a socket nothing to be bound to, so ProTUN must not hear that
    /// the network is available.
    @Test
    func usablePathWithoutAPhysicalInterfaceIsReportedAsNoNetwork() {
        let noInterface = NetworkPath(status: .satisfied, gateways: [], supportsIPv4: true, supportsIPv6: false)

        #expect(NetworkPath.eventFromUpdates(old: .initial, new: noInterface) == nil)
        #expect(NetworkPath.eventFromUpdates(old: cellular, new: noInterface) == .down)
    }

    /// An interface on a path the system does not call usable is not a network for ProTUN either.
    @Test
    func unusablePathWithAPhysicalInterfaceIsReportedAsNoNetwork() {
        let unusable = NetworkPath(
            status: .unsatisfied,
            interfaceName: "en0",
            interfaceIndex: 23,
            interfaceType: .wifi,
            gateways: [],
            supportsIPv4: false,
            supportsIPv6: false
        )

        #expect(NetworkPath.eventFromUpdates(old: .initial, new: unusable) == nil)
        #expect(NetworkPath.eventFromUpdates(old: cellular, new: unusable) == .down)
    }
}
