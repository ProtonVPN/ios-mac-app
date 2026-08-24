//
//  Created on 11/08/2026 by Max Kupetskyi.
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

import Dependencies
import Foundation

/// Bytes the tunnel interfaces have carried, summed modulo 2³² over every `utun` interface.
///
/// Each per-interface counter wraps at 2³², and the sum wraps the same way, so deltas taken
/// with wrapping subtraction remain exact as long as less than 4 GiB moves per interval.
struct InterfaceTraffic: Equatable, Sendable {
    var downloadBytes: UInt32 = 0
    var uploadBytes: UInt32 = 0

    /// Adds another interface's counters, wrapping at 2³² the way the counters themselves do.
    mutating func add(_ other: InterfaceTraffic) {
        downloadBytes &+= other.downloadBytes
        uploadBytes &+= other.uploadBytes
    }
}

/// Transfer rate in bytes per second, which the header shows next to the protocol name.
struct Bitrate: Equatable, Sendable {
    var download: UInt32
    var upload: UInt32

    static let zero = Bitrate(download: 0, upload: 0)
}

extension Bitrate {
    /// The rate between two counter readings taken `interval` apart.
    ///
    /// The counters are 32 bit and wrap at 2³². Wrapping subtraction recovers the exact number
    /// of bytes moved as long as fewer than 2³² bytes moved during the interval.
    ///
    /// - Note: If a `utun` interface disappears between readings (e.g. a VPN reconnect), the
    ///   summed counters drop and one interval reports a bogus rate; it is clamped to
    ///   `UInt32.max` at worst and corrects itself on the next reading.
    init(previous: InterfaceTraffic, current: InterfaceTraffic, interval: TimeInterval) {
        func rate(previous: UInt32, current: UInt32) -> UInt32 {
            guard interval > 0 else { return 0 }
            let moved = current &- previous
            let perSecond = (TimeInterval(moved) / interval).rounded()
            guard perSecond >= 0 else { return 0 }
            return perSecond >= TimeInterval(UInt32.max) ? UInt32.max : UInt32(perSecond)
        }

        self.init(
            download: rate(previous: previous.downloadBytes, current: current.downloadBytes),
            upload: rate(previous: previous.uploadBytes, current: current.uploadBytes)
        )
    }
}

/// Reads the tunnel interfaces' byte counters.
struct NetworkTrafficClient: Sendable {
    /// Download and upload bytes summed over every `utun` interface.
    var counters: @Sendable () -> InterfaceTraffic
}

extension NetworkTrafficClient: DependencyKey {
    static let liveValue = NetworkTrafficClient(counters: { readTunnelCounters() })

    static let testValue = NetworkTrafficClient(counters: { InterfaceTraffic() })

    /// Sums the byte counters of every tunnel interface the system reports.
    private static func readTunnelCounters() -> InterfaceTraffic {
        var addresses: UnsafeMutablePointer<ifaddrs>?
        guard getifaddrs(&addresses) == 0 else { return InterfaceTraffic() }
        defer { freeifaddrs(addresses) }

        var total = InterfaceTraffic()
        var next = addresses
        while let address = next {
            if let traffic = tunnelCounters(of: address) {
                total.add(traffic)
            }
            next = address.pointee.ifa_next
        }
        return total
    }

    /// The interface's byte counters, or `nil` when it is not a tunnel interface.
    private static func tunnelCounters(of interface: UnsafeMutablePointer<ifaddrs>) -> InterfaceTraffic? {
        // `ifa_addr` is documented to be null for some entries.
        guard let address = interface.pointee.ifa_addr,
              address.pointee.sa_family == UInt8(AF_LINK)
        else { return nil }

        let name = String(cString: interface.pointee.ifa_name)
        guard name.hasPrefix("utun"), let data = interface.pointee.ifa_data else { return nil }

        // For AF_LINK entries the kernel vends `ifa_data` as `struct if_data`, so the memory
        // is already bound to that type; asserting the binding avoids the undefined behavior
        // of reinterpreting the pointer with `unsafeBitCast`.
        let interfaceData = data.assumingMemoryBound(to: if_data.self)
        return InterfaceTraffic(
            downloadBytes: interfaceData.pointee.ifi_ibytes,
            uploadBytes: interfaceData.pointee.ifi_obytes
        )
    }
}

extension DependencyValues {
    var networkTraffic: NetworkTrafficClient {
        get { self[NetworkTrafficClient.self] }
        set { self[NetworkTrafficClient.self] = newValue }
    }
}
