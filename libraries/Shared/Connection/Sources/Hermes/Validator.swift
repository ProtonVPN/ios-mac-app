//
//  Created on 17/04/2025 by adam.
//
//  Copyright (c) 2025 Proton AG
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
private import Network

public enum HermesResolverLocationValidator {
    public enum Transport {
        case doh
        case tls
        case classic
    }

    public static func isValid(_ location: String) -> Transport? {
        if isValidHTTPS(location) {
            return .doh
        }
        if isValidTLS(location) {
            return .tls
        }
        if isValidIPv4(location) || isValidIPv6(location) {
            return .classic
        }
        return nil
    }

    // A valid TLS resolver as a string can be also seen as a valid classic Hermes IPv4 Resolver
    // So for now, let's validate the scheme as `tls` but in the future, we might want to check if TLS is available
    // for this IP address & if not, consider the IP as a classic one
    private static func isValidTLS(_ location: String) -> Bool {
        guard let url = URL(string: location) else { return false }
        return url.scheme == "tls" && url.host() != nil
    }

    private static func isValidHTTPS(_ location: String) -> Bool {
        guard let url = URL(string: location) else { return false }
        return url.scheme == "https" && url.host() != nil
    }

    private static func isValidIPv4(_ location: String) -> Bool {
        location.components(separatedBy: ".").count == 4 && IPv4Address(location) != nil
    }

    private static func isValidIPv6(_ location: String) -> Bool {
        IPv6Address(location) != nil
    }
}
