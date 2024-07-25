//
//  Created on 24/7/24.
//
//  Copyright (c) 2024 Proton AG
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

extension String {

    var isValidIPv4Address: Bool {
        // Define the IPv4 address pattern
        let ipAddressPattern = #"^(25[0-5]|2[0-4][0-9]|[0-1]?[0-9]{1,2})(\.(25[0-5]|2[0-4][0-9]|[0-1]?[0-9]{1,2})){3}$"#

        // Create the regular expression
        let regex = try? NSRegularExpression(pattern: ipAddressPattern, options: [])
        
        // Check if the string matches the pattern
        let range = NSRange(location: 0, length: self.count)
        let match = regex?.firstMatch(in: self, options: [], range: range)
        
        // Return true if a match is found
        return match != nil
    }
}
