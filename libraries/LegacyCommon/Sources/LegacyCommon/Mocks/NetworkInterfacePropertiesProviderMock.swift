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
//  along with ProtonVPN.  If not, see <https://www.gnu.org/licenses/>.

#if DEBUG
import Foundation
import Network

public class NetworkInterfacePropertiesProviderMock: NetworkInterfacePropertiesProvider {
    var interfaces: [NetworkInterface] = [
        .init(
            name: "en0",
            addr: IPv4Address("10.0.1.2")!,
            mask: IPv4Address("255.255.255.0")!,
            dest: IPv4Address("10.0.1.255")!,
            flags: [.up, .running]
        ),
        .init(
            name: "lo0",
            addr: IPv4Address("127.0.0.1")!,
            mask: IPv4Address("255.0.0.0")!,
            dest: IPv4Address("127.255.255.255")!,
            flags: [.up, .running, .loopback]
        )
    ]

    public func withNetworkInterfaceInfo<T>(_ closure: ([NetworkInterface]) throws -> T) throws -> T {
        try closure(interfaces)
    }
}
#endif
