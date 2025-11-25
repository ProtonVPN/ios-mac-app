//
//  Created on 2022-02-16.
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

public extension Array {
    /// Two-way filter: get the values that did not match the filter, in addition to the ones that did.
    /// - Returns: A tuple containing two arrays: the first with elements matching the filter, the second with non-matches.
    func filter2(_ isIncluded: (Element) throws -> Bool) rethrows -> ([Element], [Element]) {
        var yes = [Element]()
        var no = [Element]()
        for elem in self {
            if try isIncluded(elem) {
                yes.append(elem)
            } else {
                no.append(elem)
            }
        }
        return (yes, no)
    }
}
