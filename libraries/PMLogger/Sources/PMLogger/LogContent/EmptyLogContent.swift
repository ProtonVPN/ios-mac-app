//
//  Created on 2022-06-09.
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

/// Empty content used when any content should be provided instead of the unsupported one.
/// For example, OSLogContent is available only on ios 15+, so on ios 14 and older `EmptyLogContent` can be returned instead.
public class EmptyLogContent: LogContent {
    
    public init() {
    }

    public func loadContent(callback: @escaping (String) -> Void) {
        callback("")
    }
    
}
