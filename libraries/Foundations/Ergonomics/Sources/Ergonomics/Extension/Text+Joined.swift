//
//  Created on 15/11/2024.
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

import SwiftUI

public protocol Joinable {
    func joined(to other: Self, with separator: Self) -> Self
}

extension Text: Joinable {
    public func joined(to other: Self, with separator: Self) -> Self {
        return self + separator + other
    }
}

extension Collection where Element: Joinable {
    public func joined(separator: Self.Element) -> Self.Element? {
        guard let first else { return nil }
        return dropFirst().reduce(first) { $0.joined(to: $1, with: separator) }
    }
}
