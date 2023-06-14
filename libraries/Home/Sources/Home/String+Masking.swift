//
//  Created on 18/05/2023.
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
    /// This method will return the copy of a string with the same length, but with 1 random character changed to an asterisk.
    /// It's used for the "protecting" animation in the connection status view.
    func partiallyMasked() -> String? {
        // pick a random character
        let random = shuffled().first { $0 != "*" }
        guard let random,
              // Find the range of the first occurrence
              let range = range(of: String(random)) else {
            return nil
        }
        var masked = self
        masked.replaceSubrange(range, with: "*")
        guard masked != self else {
            // return nil to indicate that there are no more characters to change
            return nil
        }
        return masked
    }
}
