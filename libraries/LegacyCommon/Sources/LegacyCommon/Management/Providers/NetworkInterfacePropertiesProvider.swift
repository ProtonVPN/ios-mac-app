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

import Foundation
import Network

public protocol NetworkInterfacePropertiesProvider {
    func withNetworkInterfaceInfo<T>(_ closure: ([NetworkInterface]) throws -> T) throws -> T
}

public protocol NetworkInterfacePropertiesProviderFactory {
    func makeInterfacePropertiesProvider() -> NetworkInterfacePropertiesProvider
}

public class NetworkInterfacePropertiesProviderImplementation: NetworkInterfacePropertiesProvider {
    public func withNetworkInterfaceInfo<T>(_ closure: ([NetworkInterface]) throws -> T) throws -> T {
        var addrs: UnsafeMutablePointer<ifaddrs>?

        guard getifaddrs(&addrs) == 0 else {
            throw POSIXError(.init(rawValue: errno) ?? .ELAST)
        }

        var result: [NetworkInterface] = []
        while let addr = addrs?.pointee {
            result.append(NetworkInterface(addr))
            addrs = addr.ifa_next
        }

        freeifaddrs(addrs)

        return try closure(result)
    }
}

public struct NetworkInterface {
    let name: String?
    let addr: IPAddress?
    let mask: IPAddress?
    let dest: IPAddress?
    let flags: Flags

    struct Flags: OptionSet {
        let rawValue: Int32

        static let up = Self(rawValue: IFF_UP)
        static let running = Self(rawValue: IFF_RUNNING)
        static let pointToPoint = Self(rawValue: IFF_POINTOPOINT)
        static let loopback = Self(rawValue: IFF_LOOPBACK)
    }
}

extension NetworkInterface {
    private static func ip(_ sockaddrPtr: UnsafeMutablePointer<sockaddr>!) -> IPAddress? {
        guard let sockaddrPtr else { return nil }

        switch Int32(sockaddrPtr.pointee.sa_family) {
        case AF_INET:
            return sockaddrPtr.withMemoryRebound(to: sockaddr_in.self, capacity: 1) {
                IPv4Address($0.pointee)
            }
        case AF_INET6:
            return sockaddrPtr.withMemoryRebound(to: sockaddr_in6.self, capacity: 1) {
                IPv6Address($0.pointee)
            }
        default:
            return nil
        }
    }

    init(_ interface: ifaddrs) {
        if let nameCString = interface.ifa_name {
            name = String(cString: nameCString)
        } else {
            name = nil
        }

        addr = Self.ip(interface.ifa_addr)
        mask = Self.ip(interface.ifa_netmask)
        dest = Self.ip(interface.ifa_dstaddr)
        flags = Flags(rawValue: Int32(interface.ifa_flags))
    }
}

extension IPv4Address {
    init?(_ addr: sockaddr_in) {
        assert(addr.sin_family == AF_INET)
        let data = withUnsafePointer(to: addr.sin_addr) {
            Data(bytes: $0, count: MemoryLayout<in_addr>.size)
        }

        self.init(data)
    }
}

extension IPv6Address {
    init?(_ addr: sockaddr_in6) {
        assert(addr.sin6_family == AF_INET6)
        let data = withUnsafePointer(to: addr.sin6_addr) {
            Data(bytes: $0, count: MemoryLayout<in6_addr>.size)
        }

        self.init(data)
    }
}
