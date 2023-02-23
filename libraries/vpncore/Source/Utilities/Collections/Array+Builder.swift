//
//  Created on 21/12/2022.
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

/// Functional style array builder functions
extension Array where Element: Equatable {

    /// Returns a copy of this array, without any occurrences of `element`.
    public func removing(_ element: Element) -> [Element] {
        var copy = self
        copy.removeAll(where: { $0 == element })
        return copy
    }

    /// Returns a copy of this array, without any occurrences of elements contained in `elements`.
    public func removing(_ elements: any Collection<Element>) -> [Element] {
        var copy = self
        elements.forEach { elementToRemove in
            copy.removeAll(where: { $0 == elementToRemove })
        }
        return copy
    }

    /// Returns a copy of this array, conditionally removing any occurrences of `element`.
    public func removing(_ element: Element, if condition: Bool) -> [Element] {
        if condition {
            return self.removing(element)
        }
        return self
    }

    /// Returns a copy of this array, conditionally removing any occurrences of elements contained in `elements`.
    public func removing(_ elements: any Collection<Element>, if condition: Bool) -> [Element] {
        if condition {
            return self.removing(elements)
        }
        return self
    }
}

extension Array {

    /// Returns a copy of this array, appending the contents of the argument.
    public func appending(_ other: Self) -> Self {
        var copy = self
        copy.append(contentsOf: other)
        return copy
    }

    /// Returns a copy of this array, appending the contents of `other` if `condition` evaluates to true.
    public func appending(_ other: Self, if condition: Bool) -> Self {
        if condition {
            return self.appending(other)
        }
        return self
    }

    /// Performance oriented overload of `appending`, which only computes the value of the `generator` closure if
    /// `condition` evalutes to true.
    public func appending(_ generator: () -> Self, if condition: Bool) -> Self {
        if condition {
            return self.appending(generator())
        }
        return self
    }
}
