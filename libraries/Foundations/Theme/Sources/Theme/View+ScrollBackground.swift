//
//  Created on 29/06/2023.
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

#if canImport(SwiftUI)
import SwiftUI

extension View {

    /// Makes the background of lists, forms and scroll views transparent
    ///
    /// - Important: This is not supported before iOS 16 and MacOS 13. On those versions, this must be achieved using
    /// older methods such as:
    ///
    /// ```swift
    /// UITableView.appearance().backgroundColor = .clear
    /// ```
    public var hidingScrollBackground: some View {
        if #available(iOS 16, macOS 13, *) {
            return self.scrollContentBackground(.hidden)
        }
        return self
    }
}
#endif
