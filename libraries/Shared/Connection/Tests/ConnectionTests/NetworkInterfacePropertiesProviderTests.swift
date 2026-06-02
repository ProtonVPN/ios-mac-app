//
//  Created on 10.08.23.
//
//  Copyright (c) 2023 Proton AG
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
//  along with Proton VPN.  If not, see <https://www.gnu.org/licenses/>.

@testable import CoreConnection
import Dependencies
import Foundation
import Network
import Testing

@Suite("NetworkInterfacePropertiesProvider.firstBadInterface")
struct FirstBadInterfaceTests {
    @Test("Properly configured networks return nil")
    func properlyConfiguredNetworksReturnNil() {
        let provider = NetworkInterfacePropertiesProvider(
            withNetworkInterfaceInfo: { [.defaultLoopback] }
        )
        #expect(provider.firstBadInterface() == nil)
    }

    @Test(
        "Weird subnets are flagged",
        arguments: [
            NetworkInterface.pretendingToBeGoogle,
            NetworkInterface.nonRfc1918WithWeirdMask,
            NetworkInterface.subnetWithWeirdMask,
        ]
    )
    func weirdSubnetsAreFlagged(weirdInterface: NetworkInterface) {
        let provider = NetworkInterfacePropertiesProvider(
            withNetworkInterfaceInfo: { [.defaultLoopback, weirdInterface] }
        )
        let bad = provider.firstBadInterface()
        #expect(bad?.name == weirdInterface.name)
    }

    @Test("Provider errors return nil")
    func providerErrorsReturnNil() {
        let provider = NetworkInterfacePropertiesProvider(
            withNetworkInterfaceInfo: { throw NSError(domain: "test", code: 1) }
        )
        #expect(provider.firstBadInterface() == nil)
    }
}

extension NetworkInterface {
    static let defaultLoopback: Self = .init(
        name: "lo0",
        addr: IPv4Address("127.0.0.1")!,
        mask: IPv4Address("255.0.0.0"),
        dest: IPv4Address("127.255.255.255"),
        flags: [.up, .running, .loopback]
    )

    /// The interface has an IP in the same /24 range as Google's IP, can be used to exfiltrate traffic.
    static let pretendingToBeGoogle: Self = .init(
        name: "en0",
        addr: IPv4Address("142.250.203.1")!,
        mask: IPv4Address("255.255.255.0")!,
        dest: IPv4Address("142.250.203.255")!,
        flags: [.up, .running]
    )

    /// The interface has an interface that at first appears to be within an RFC1918 range,
    /// except the mask is just one bit shy of masking the `10`.
    static let subnetWithWeirdMask: Self = .init(
        name: "en1",
        addr: IPv4Address("10.0.1.2")!,
        mask: IPv4Address("254.0.0.0")!,
        dest: IPv4Address("10.255.255.255")!,
        flags: [.up, .running]
    )

    /// This is similar to the Google-spoofing example, but is even more egregious.
    static let nonRfc1918WithWeirdMask: Self = .init(
        name: "en2",
        addr: IPv4Address("1.0.0.2")!,
        mask: IPv4Address("128.0.0.0")!,
        dest: IPv4Address("1.255.255.255")!,
        flags: [.up, .running]
    )
}
