//
//  Created on 19/06/2026.
//
//  Copyright (c) 2026 Proton AG
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

import simd

/// Colors that are an app concept rather than something stored in the SVG.
public enum MapStyle {
    /// Fill applied to the connected country (`#4A4658`).
    public static let highlightColor = SIMD4<Float>(Float(0x4A) / 255, Float(0x46) / 255, Float(0x58) / 255, 1)
    /// Base ocean sphere color behind the land (`#181B26`).
    public static let oceanColor = SIMD4<Float>(Float(0x18) / 255, Float(0x1B) / 255, Float(0x26) / 255, 1)
}
