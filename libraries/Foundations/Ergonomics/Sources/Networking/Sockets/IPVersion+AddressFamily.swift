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

#if canImport(Darwin)
    import Darwin
    import Ergonomics

    public extension IPVersion {
        /// The address family the socket interface uses for this version, `AF_INET` or `AF_INET6`.
        var addressFamily: CInt {
            switch self {
            case .v4: AF_INET
            case .v6: AF_INET6
            }
        }

        /// The version a socket address family stands for, or nil when the family is not an IP family.
        init?(addressFamily: CInt) {
            switch addressFamily {
            case AF_INET: self = .v4
            case AF_INET6: self = .v6
            default: return nil
            }
        }
    }
#endif
