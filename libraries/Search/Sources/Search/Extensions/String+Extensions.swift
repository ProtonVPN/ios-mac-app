//
//  Created on 04.03.2022.
//
//  Copyright (c) 2022 Proton AG
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
    var normalized: String {
        return folding(options: [.diacriticInsensitive, .caseInsensitive], locale: .current)
    }

    func findStartingRanges(of substring: String) -> [NSRange] {
        let substring = substring.trimmingCharacters(in: .whitespacesAndNewlines)

        let parts = self.components(separatedBy: CharacterSet.whitespacesAndNewlines)
        var ranges: [NSRange] = []
        var count = 0
        for part in parts {
            if part.normalized.starts(with: substring.normalized) {
                ranges.append(NSRange(location: count, length: substring.count))
            }

            count = count + part.count + 1
        }

        if ranges.isEmpty, self.normalized.starts(with: substring.normalized) {
            ranges.append(NSRange(location: 0, length: substring.count))
        }

        return ranges
    }
}
