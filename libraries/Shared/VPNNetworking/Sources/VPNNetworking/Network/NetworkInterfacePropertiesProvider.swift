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

import Dependencies
import Foundation
import Network

public struct NetworkInterfacePropertiesProvider: Sendable {
    public var withNetworkInterfaceInfo: @Sendable () throws -> [NetworkInterface]
}

extension NetworkInterfacePropertiesProvider: DependencyKey {
    public static let liveValue = Self(
        withNetworkInterfaceInfo: {
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

            return result
        }
    )

    #if DEBUG
        public static let testValue = Self(
            withNetworkInterfaceInfo: {
                [
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
                    ),
                ]
            }
        )
    #endif
}

public extension DependencyValues {
    var networkInterfacePropertiesProvider: NetworkInterfacePropertiesProvider {
        get { self[NetworkInterfacePropertiesProvider.self] }
        set { self[NetworkInterfacePropertiesProvider.self] = newValue }
    }
}

public struct NetworkInterface: Sendable {
    public let name: String?
    public let addr: IPAddress?
    public let mask: IPAddress?
    public let dest: IPAddress?
    public let flags: Flags

    public struct Flags: OptionSet, Sendable {
        public let rawValue: Int32

        public init(rawValue: Int32) {
            self.rawValue = rawValue
        }

        public static let up = Self(rawValue: IFF_UP)
        public static let running = Self(rawValue: IFF_RUNNING)
        public static let pointToPoint = Self(rawValue: IFF_POINTOPOINT)
        public static let loopback = Self(rawValue: IFF_LOOPBACK)
    }

    public init(
        name: String?,
        addr: IPAddress?,
        mask: IPAddress?,
        dest: IPAddress?,
        flags: Flags
    ) {
        self.name = name
        self.addr = addr
        self.mask = mask
        self.dest = dest
        self.flags = flags
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
            self.name = String(cString: nameCString)
        } else {
            self.name = nil
        }

        self.addr = Self.ip(interface.ifa_addr)
        self.mask = Self.ip(interface.ifa_netmask)
        self.dest = Self.ip(interface.ifa_dstaddr)
        self.flags = Flags(rawValue: Int32(interface.ifa_flags))
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
