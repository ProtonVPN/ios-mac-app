//
//  Created on 2023-04-26.
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

public extension String {
    /// Search for IPs and return string with IPs masked
    var maskIPs: String {
        maskIPv4
            .maskIPv6
    }

    /// Search for IP v4 addresses and mask last two parts
    var maskIPv4: String {
        let result = NSMutableString(string: self as NSString)
        guard let regexp = try? NSRegularExpression(pattern: "([0-9]{1,3})\\.([0-9]{1,3})\\.([0-9]{1,3})\\.([0-9]{1,3})") else {
            return self
        }
        if regexp.replaceMatches(
            in: result,
            range: NSRange(location: 0, length: count),
            withTemplate: "$1.$2.*.*"
        ) > 0 {
            return String(result)
        } else {
            return self
        }
    }

    /// Search for IP v6 addresses and mask the IP
    var maskIPv6: String {
        let result = NSMutableString(string: self as NSString)
        guard let regexp = try? NSRegularExpression(pattern: "([a-f0-9:]+:+)+[a-f0-9]+") else {
            return self
        }
        if regexp.replaceMatches(
            in: result,
            range: NSRange(location: 0, length: count),
            withTemplate: "ip:v6:removed"
        ) > 0 {
            return String(result)
        } else {
            return self
        }
    }
}
