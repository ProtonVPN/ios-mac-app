//
//  Created on 2023-07-19.
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

extension Array {
    /// Accepts optional closure for filtering. If `nil` is given, return the same array unfiltered.
    public func filter(_ isIncluded: ((Element) throws -> Bool)?) rethrows -> [Element] {
        guard let isIncluded else { return self }
        return try self.filter { try isIncluded($0) }
    }
}
