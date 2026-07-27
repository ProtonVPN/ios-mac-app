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
import MapShaderTypes
import simd
import Triangulation

/// The celestial geometry: the Sun and Moon positions and the fixed starfield, in the model-space form the
/// globe renderer consumes. The positions are sampled at creation, and the owning view re-creates the
/// value on a slow clock, since both bodies drift only about a quarter of a degree per minute.
///
/// Holds only astronomy and the starfield. The connection-colored sun tint and its cross-fade are a
/// SwiftUI animation concern and stay with the view. This type imports no UI.
struct CelestialPresentation {
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

    /// A fixed-instant presentation computed once per process, for cheap `@State` declaration defaults
    /// (SwiftUI evaluates those on every view re-`init`, and the full ephemeris is too expensive for
    /// that). The owning view replaces it with the real positions on its first task tick, before the
    /// day/night lighting is ever faded in, so the placeholder instant is never visible.
    static let placeholder = CelestialPresentation(date: Date(timeIntervalSince1970: 1_781_784_000))

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

    /// The starfield as Metal instances: 500 stars spread uniformly over the celestial sphere. Built once,
    /// with a fixed seed so the field is identical on every run.
    static let starInstances: [StarInstance] = {
        var rng = SeededGenerator(seed: 0x3135_3231_3372_6F78)
        return (0 ..< 500).map { _ in
            // Uniform point on the unit sphere (z uniform, azimuth uniform).
            let z = Double.random(in: -1 ... 1, using: &rng)
            let azimuth = Double.random(in: 0 ... (2 * Double.pi), using: &rng)
            let ring = (1 - z * z).squareRoot()
            let direction = SIMD3<Float>(Float(ring * cos(azimuth)), Float(z), Float(-ring * sin(azimuth)))
            let radius = Double.random(in: 0.4 ... 1.5, using: &rng)
            let brightness = Double.random(in: 0.25 ... 0.9, using: &rng)
            return StarInstance(direction: direction, radius: Float(radius), brightness: Float(brightness))
        }
    }()

    /// Star visibility: 0 until the camera pulls out past the whole-globe distance, ramping to full at the
    /// zoom-out `ceiling`. Purely zoom-driven. The lighting's own `lightFade` already keeps the stars off in
    /// decorative mode, so gating on the interactive flag here would only make them pop.
    static func starOpacity(atDistance distance: Float, ceiling: Float) -> Float {
        ramp(distance, from: GlobeFocus.wholeGlobeDistance, to: ceiling)
    }
}

/// Tiny seeded LCG so the star field is stable across renders without depending on a global RNG.
private struct SeededGenerator: RandomNumberGenerator {
    private var state: UInt64
    init(seed: UInt64) {
        self.state = seed
    }

    mutating func next() -> UInt64 {
        state = state &* 6_364_136_223_846_793_005 &+ 1_442_695_040_888_963_407
        return state
    }
}
