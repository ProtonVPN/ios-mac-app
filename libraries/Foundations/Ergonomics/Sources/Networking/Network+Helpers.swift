//
//  Created on 07/07/2026.
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

#if canImport(Network)
    import Network

    public extension NWEndpoint {
        var ipv4String: String? {
            guard
                case let .hostPort(host, _) = self,
                case let .ipv4(addr) = host
            else { return nil }

            return addr.asString
        }
    }

    public extension IPv4Address {
        /// The address as one host-order integer for quick comparison.
        var packed: UInt32 {
            rawValue.withUnsafeBytes { $0.loadUnaligned(as: UInt32.self).bigEndian }
        }

        /// Reads the address as a subnet mask and returns its prefix length.
        var prefixLength: Int {
            (~packed).leadingZeroBitCount
        }

        var in_addr_value: in_addr {
            rawValue.withUnsafeBytes { $0.load(as: in_addr.self) }
        }

        var asString: String? {
            withUnsafeTemporaryAllocation(of: CChar.self, capacity: Int(INET_ADDRSTRLEN)) { addrBuffer in
                var addr = in_addr_value
                guard inet_ntop(AF_INET, &addr, addrBuffer.baseAddress, socklen_t(INET_ADDRSTRLEN)) != nil else {
                    return nil
                }
                return String(cString: addrBuffer.baseAddress!)
            }
        }
    }

    public extension IPv6Address {
        /// The address as two host-order integers for quick comparison.
        var packed: (hi: UInt64, lo: UInt64) {
            rawValue.withUnsafeBytes { raw in
                (
                    raw.loadUnaligned(fromByteOffset: 0, as: UInt64.self).bigEndian,
                    raw.loadUnaligned(fromByteOffset: 8, as: UInt64.self).bigEndian
                )
            }
        }

        var in6_addr_value: in6_addr {
            rawValue.withUnsafeBytes { $0.load(as: in6_addr.self) }
        }

        var asString: String? {
            withUnsafeTemporaryAllocation(of: CChar.self, capacity: Int(INET6_ADDRSTRLEN)) { addrBuffer in
                var addr = in6_addr_value
                guard inet_ntop(AF_INET6, &addr, addrBuffer.baseAddress, socklen_t(INET6_ADDRSTRLEN)) != nil else {
                    return nil
                }
                return String(cString: addrBuffer.baseAddress!)
            }
        }
    }
#endif
