//
//  Created on 20/07/2023.
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

#if canImport(Cocoa)
import Cocoa

/// Use this method to force the usage of dark theme on macOS, where we set the background color using CGColor
@available(macOS 11, *)
public struct DarkAppearance {
    @discardableResult
    public init(_ draw: () -> Void) {
        NSAppearance(named: .darkAqua)?.performAsCurrentDrawingAppearance {
            draw()
        }
    }
}

#endif
