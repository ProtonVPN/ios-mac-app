//
//  Created on 30.06.2026 by John Biggs.
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

import CoreGraphics

/// Clamped 0-to-1 progress across an interval: `ramp(x, from: a, to: b)` is `(x - a) / (b - a)` clamped to `[0, 1]`.
/// This "fade in across this interval" shape recurs throughout the map's motion, in the pole-zoom proximity and the
/// pill's label fade. Generic so it serves `Float` (camera) and `CGFloat` (UI) alike. Returns 0 for a zero-width
/// interval.
func ramp<Value: BinaryFloatingPoint>(_ x: Value, from: Value, to: Value) -> Value {
    guard to != from else { return 0 }
    return max(0.0, min(1.0, (x - from) / (to - from)))
}

/// Linear interpolation `a + (b - a) * t`. `t` is unclamped, so pair it with `ramp` when it needs bounding.
func lerp<Value: BinaryFloatingPoint>(_ a: Value, _ b: Value, _ t: Value) -> Value {
    a + (b - a) * t
}
