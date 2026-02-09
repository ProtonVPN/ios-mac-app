//
//  Created on 28/01/2026 by Max Kupetskyi.
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
import SwiftUI
import Theme

package func highlightedText(_ text: String, searchText: String) -> Text {
    let lowercasedText = text.lowercased()
    let lowercasedSearch = searchText.lowercased()

    if let range = lowercasedText.range(of: lowercasedSearch) {
        let beforeMatch = String(text[..<range.lowerBound])
        let match = String(text[range])
        let afterMatch = String(text[range.upperBound...])

        return Text(beforeMatch)
            .foregroundColor(Color(.text))
            + Text(match)
            .foregroundColor(.yellow)
            .fontWeight(.bold)
            + Text(afterMatch)
            .foregroundColor(Color(.text))
    }

    return Text(text)
        .foregroundColor(Color(.text))
}
