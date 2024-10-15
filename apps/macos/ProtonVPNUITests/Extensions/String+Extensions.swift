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
    
    var trimServerCode: String {
        // Regular expression pattern to match the server code at the end of the string
        let pattern = "\\b[A-Z]{2}(?:-[A-Z]{2})?#\\d+$"
        
        do {
            let regex = try NSRegularExpression(pattern: pattern, options: [])
            let range = NSRange(location: 0, length: self.count)
            
            // Replace the matched pattern with an empty string
            let trimmedString = regex.stringByReplacingMatches(in: self, options: [], range: range, withTemplate: "")
            
            // Trim any trailing whitespace that might be left
            return trimmedString.trimmingCharacters(in: .whitespacesAndNewlines)
        } catch let error {
            return self
        }
    }
}
