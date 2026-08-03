//
//  Created on 29.06.2026 by John Biggs.
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

/// A geometric angle that owns its degree/radian conversion, so the rest of the module never juggles `* .pi / 180` by
/// hand. Backed by radians. Degrees are derived.
@frozen
public struct Angle: Equatable, Comparable, Sendable, BitwiseCopyable {
    public let radians: Double

    public var degrees: Double {
        radians * 180 / .pi
    }

    public static func degrees(_ d: Double) -> Angle {
        Angle(radians: d * .pi / 180)
    }

    public static func radians(_ r: Double) -> Angle {
        Angle(radians: r)
    }

    /// `asin`, `acos`, and `atan2` that hand back an `Angle` rather than a bare radian `Double`, so a coordinate
    /// rotation can read `.atan2(y, x)` instead of `.radians(atan2(y, x))`.
    public static func asin(_ x: Double) -> Angle {
        .radians(Foundation.asin(x))
    }

    public static func acos(_ x: Double) -> Angle {
        .radians(Foundation.acos(x))
    }

    public static func atan2(_ y: Double, _ x: Double) -> Angle {
        .radians(Foundation.atan2(y, x))
    }

    public static func + (a: Angle, b: Angle) -> Angle {
        Angle(radians: a.radians + b.radians)
    }

    public static func - (a: Angle, b: Angle) -> Angle {
        Angle(radians: a.radians - b.radians)
    }

    /// Scalar multiples. Lets a periodic term combine angles with integer multipliers, and lets a series read `sin(2 *
    /// M)` the way the textbook writes it.
    public static func * (k: Double, a: Angle) -> Angle {
        Angle(radians: k * a.radians)
    }

    public static func * (k: Int, a: Angle) -> Angle {
        Double(k) * a
    }

    /// Signed ordering on radians (minus 90 degrees is less than 45), so an angle can be `max`/`min` reduced or
    /// compared against a threshold without unwrapping to `radians`.
    public static func < (a: Angle, b: Angle) -> Bool {
        a.radians < b.radians
    }

    /// Wrapped into (-180, 180] degrees, east-positive geographic longitude. -180 normalises to +180, so the
    /// antimeridian has a single normal form whichever side it's approached from.
    public var normalizedSigned: Angle {
        var d = degrees.truncatingRemainder(dividingBy: 360)
        if d > 180 { d -= 360 } else if d <= -180 { d += 360 }
        return .degrees(d)
    }
}

// Trig overloads taking an `Angle`, so the rotations and series throughout the module read like the textbook:
// `sin(longitude)` rather than `sin(longitude.radians)`. The `Angle` owns the radian conversion and these only unwrap
// it, so the call sites never see `* .pi / 180`.
func sin(_ a: Angle) -> Double {
    Foundation.sin(a.radians)
}

func cos(_ a: Angle) -> Double {
    Foundation.cos(a.radians)
}

func tan(_ a: Angle) -> Double {
    Foundation.tan(a.radians)
}
