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

import Dependencies
import Foundation
import Triangulation

/// The bodies that move on the clock — the Sun and Moon — sampled at an instant and shaped into what the
/// globe renderer consumes. The owning view re-creates the value on a slow clock, since both bodies drift
/// only about a quarter of a degree per minute.
///
/// The fixed backdrop is `Starfield`'s, not this type's: the split follows lifecycle — time-driven and
/// dependency-sampled here versus seed-driven and built once there. The connection-colored sun tint and
/// its cross-fade are a SwiftUI animation concern and stay with the view. This type imports no UI.
struct SolarSystem {
    /// Geocentric Sun and Moon positions: sub-solar and sub-lunar directions plus the Moon distance.
    let positions: Meeus.Positions

    init(date: Date) {
        self.positions = Meeus.positions(at: date)
    }

    /// Samples at the controlled current date (`\.date.now`) rather than a bare `Date()`, so tests can pin
    /// the Sun and Moon by scoping a date override around rendering.
    init() {
        @Dependency(\.date.now) var now
        self.init(date: now)
    }

    /// A fixed-instant sample computed once per process, for cheap `@State` declaration defaults (SwiftUI
    /// evaluates those on every view re-`init`, and the full ephemeris is too expensive for that). The
    /// owning view replaces it with the real positions on its first task tick, before the day/night
    /// lighting is ever faded in, so the placeholder instant is never visible.
    static let placeholder = SolarSystem(date: Date(timeIntervalSince1970: 1_781_784_000))

    /// Model-space direction toward the sun (the sub-solar point). Drives the day/night terminator and the
    /// sun glow.
    var sunDirection: SIMD3<Float> {
        positions.sunDirection
    }

    /// Model-space position of the Moon's centre: the sub-lunar direction scaled by its true distance in
    /// Earth radii.
    var moonCenter: SIMD3<Float> {
        positions.moonDirection * positions.moonDistance
    }

    /// Moon radius in Earth radii. The Moon is rendered true to scale.
    var moonRadius: Float {
        CelestialConstants.moonRadiusEarthRadii
    }
}
