//
//  Created on 26.06.2026 by John Biggs.
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

import Foundation
import Network

/// Marshalling helpers for converting IP addresses between strings and raw bytes.
public enum IPAddressPacking {
    /// Render a pointer to a buffer containing an IP address to a String, if possible.
    public static func string(_ raw: UnsafeRawBufferPointer) -> String? {
        let ip: (any IPAddress)? = switch raw.count {
        case IPv4Address.size:
            IPv4Address(raw)
        case IPv6Address.size:
            IPv6Address(raw)
        default:
            nil
        }

        return ip.map { "\($0)" }
    }

    /// Writes `address`'s raw bytes (not the String) into `raw`, or zeroes the buffer when `address` is `nil`.
    public static func write(_ address: (any IPAddress)?, into raw: UnsafeMutableRawBufferPointer) {
        for index in raw.indices {
            raw[index] = 0
        }
        guard let rawValue = address?.rawValue else { return }
        guard rawValue.count == raw.count else {
            assertionFailure("IP address packed to \(rawValue.count) bytes, expected \(raw.count)")
            return
        }
        rawValue.withUnsafeBytes { raw.copyMemory(from: $0) }
    }
}

private extension IPAddress {
    init?(_ raw: UnsafeRawBufferPointer) {
        guard raw.contains(where: { $0 != 0 }) else { return nil }
        guard let dangerous = UnsafeMutableRawBufferPointer(mutating: raw).baseAddress else { return nil }

        // Data wants an `UnsafeMutableBufferPointer`, but it's ok to lie as long as we only admire the bytes.
        let data = Data(bytesNoCopy: dangerous, count: raw.count, deallocator: .none)
        guard let value = Self(data, nil) else { return nil }
        self = value
    }
}

private extension IPv4Address {
    static let size = 4
}

private extension IPv6Address {
    static let size = 16
}
