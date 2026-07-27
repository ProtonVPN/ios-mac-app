//
//  Created on 23/07/2026.
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

import Foundation
import MapShaderTypes
import simd
import Triangulation

/// The fixed pinpoint-star backdrop: the celestial sphere the globe renders against, generated once per
/// process from a fixed seed so the field is identical on every run.
///
/// Placement is not uniform. A candidate star's chance of being kept follows a density field with two
/// factors: a Gaussian band around the real galactic plane (oriented by `CelestialConstants
/// .galacticNorthPole`, so the Milky Way's star river crosses the sky where it actually belongs) and
/// low-frequency gradient noise that breaks the band into patches. Magnitudes are skewed the way real
/// skies are — many faint stars, few bright — and stars inside the band glow slightly brighter.
///
/// This type owns only the discrete stars; the Milky Way's diffuse body is a continuous analytic pass in
/// the renderer (`fragment_skyglow`), because discrete billboards can't make smooth haze without resolving
/// as discs. The two share the galactic frame, so the star river and the glow coincide.
///
/// Time-independent by design, unlike `SolarSystem`: the whole field is Earth-fixed (no sidereal
/// rotation), which is physically a fixed-epoch convention but visually indistinguishable, and is what
/// lets the field be built once and cached.
enum Starfield {
    /// The field the app renders. Built lazily on first use, once per process.
    static let instances: [StarInstance] = instances(
        seed: Constants.seed,
        count: Constants.count,
        bandStrength: Constants.bandStrength
    )

    /// Star visibility: 0 until the camera pulls out past the whole-globe distance, ramping to full at the
    /// zoom-out `ceiling`. Purely zoom-driven. The lighting's own `lightFade` already keeps the stars off
    /// in decorative mode, so gating on the presentation here would only make them pop.
    static func opacity(atDistance distance: Float, ceiling: Float) -> Float {
        ramp(distance, from: GlobeFocus.wholeGlobeDistance, to: ceiling)
    }

    /// Deterministic generation of the pinpoint stars, parameterized so tests can pin the density contract
    /// and tuning can A/B against `bandStrength: 0` (a plain uniform sky). Dense along the galactic band,
    /// sparse elsewhere — the visible river of stars, which sits over the renderer's analytic glow.
    static func instances(seed: UInt64, count: Int, bandStrength: Float) -> [StarInstance] {
        var rng = SeededGenerator(seed: seed)
        let noise = GradientNoise(using: &rng)
        // Rejection sampling can never exceed the density's two summed factors, so this bound keeps the
        // acceptance draw tight (no wasted rejections against headroom that can't occur).
        let densityCeiling = Constants.baseDensity + max(0, bandStrength)

        var stars: [StarInstance] = []
        stars.reserveCapacity(count)
        while stars.count < count {
            // Uniform candidate on the unit sphere (z uniform, azimuth uniform), kept with probability
            // proportional to the local density. `baseDensity > 0` guarantees progress even far from the
            // band.
            let (direction, bandFactor) = candidate(using: &rng, noise: noise)
            let density = Constants.baseDensity + bandStrength * bandFactor
            guard Float.random(in: 0 ..< densityCeiling, using: &rng) < density else { continue }

            // Skewed magnitudes: squaring the uniform draw crowds the low end, giving the many-faint /
            // few-bright distribution of a real sky. Band members get a small brightness lift on top, so
            // the band glows as a feature instead of only densifying.
            let magnitude = Float.random(in: 0 ... 1, using: &rng)
            let skewed = magnitude * magnitude
            stars.append(StarInstance(
                direction: direction,
                radius: Constants.radiusRange.lowerBound
                    + skewed * (Constants.radiusRange.upperBound - Constants.radiusRange.lowerBound),
                brightness: Constants.brightnessRange.lowerBound
                    + skewed * (Constants.brightnessRange.upperBound - Constants.brightnessRange.lowerBound)
                    + Constants.bandGlow * bandFactor
            ))
        }
        return stars
    }

    /// One uniform unit-sphere candidate and its band factor, shared by the star and glow samplers.
    private static func candidate(
        using rng: inout SeededGenerator,
        noise: GradientNoise
    ) -> (direction: SIMD3<Float>, bandFactor: Float) {
        let z = Double.random(in: -1 ... 1, using: &rng)
        let azimuth = Double.random(in: 0 ..< 2 * Double.pi, using: &rng)
        let ring = (1 - z * z).squareRoot()
        let direction = SIMD3<Float>(Float(ring * cos(azimuth)), Float(z), Float(-ring * sin(azimuth)))
        return (direction, bandFactor(at: direction, noise: noise))
    }

    /// The structured part of the density at `direction`, in [0, 1]: the galactic-plane Gaussian times the
    /// patchiness noise. Factored out so the sampler and the brightness lift can't disagree about where
    /// the band is.
    private static func bandFactor(at direction: SIMD3<Float>, noise: GradientNoise) -> Float {
        // sin of the galactic latitude: 0 on the plane, ±1 at the galactic poles.
        let sinLatitude = simd_dot(direction, CelestialConstants.galacticNorthPole)
        let band = exp(-(sinLatitude * sinLatitude) / (2 * Constants.bandSigma * Constants.bandSigma))
        let patchiness = 0.5 + 0.5 * noise.value(at: direction * Constants.patchFrequency)
        return band * max(0, min(1, patchiness))
    }

    /// Internal (not private) so `StarfieldTests` can assert the ranges and counts it pins.
    enum Constants {
        /// Fixed seed, so the field is identical on every run (and in every snapshot).
        static let seed: UInt64 = 0x3135_3231_3372_6F78
        /// A dense pinpoint field: the river of stars along the band is the Milky Way's primary cue, and in
        /// portrait at the maximum zoom-out the globe overflows the frame horizontally, leaving only thin
        /// sky windows above and below it (~1% of the sphere). The count is set so those windows carry a
        /// legible stipple rather than a scatter. Instanced billboards built once per process, nearly free.
        static let count = 5000
        /// Acceptance probability far from the band. Low enough that the off-band sky is clearly sparser
        /// than the band, high enough that it never reads as empty; also bounds the rejection loop away
        /// from starvation.
        static let baseDensity: Float = 0.12
        /// Weight of the band term for the shipped field. With `baseDensity` this puts the in-band sky at
        /// up to ~8× the off-band density in the cloud cores, which `StarfieldTests` pins as "at least 2×".
        static let bandStrength: Float = 0.9
        /// Width of the star band as the standard deviation of sin(galactic latitude); 0.13 is a band about
        /// 7.5 degrees to a side, tight enough to read as a river through the app's visible sky windows.
        static let bandSigma: Float = 0.13
        /// Spatial frequency of the patchiness noise: ~2.5 cycles across the sphere, big soft clouds
        /// rather than speckle.
        static let patchFrequency: Float = 2.5
        /// Rendered size and brightness spans for point stars: small and crisp (the shader keeps anything
        /// under `pointCrispRadius` sharp), so they read as pinpoints, not soft dots.
        static let radiusRange: ClosedRange<Float> = 0.35 ... 1.3
        static let brightnessRange: ClosedRange<Float> = 0.2 ... 0.9
        /// Extra brightness for stars sitting in the band's glow, on top of `brightnessRange`.
        static let bandGlow: Float = 0.12
    }
}

// MARK: - Noise

/// Classic improved-Perlin 3D gradient noise over a seeded permutation lattice: smooth, roughly [-1, 1],
/// with features about one unit across. Sampled at (scaled) unit-sphere directions, which avoids the polar
/// pinching a UV-mapped 2D noise would show. Private to the starfield until a second consumer appears.
private struct GradientNoise {
    /// The permutation table, doubled so `table[hash + 1]` never wraps.
    private let table: [Int]

    /// Builds the lattice from the shared seeded generator (Fisher–Yates), so a `Starfield` seed pins the
    /// noise field along with everything else.
    init(using rng: inout SeededGenerator) {
        var permutation = Array(0 ..< 256)
        for i in stride(from: 255, through: 1, by: -1) {
            permutation.swapAt(i, Int.random(in: 0 ... i, using: &rng))
        }
        self.table = permutation + permutation
    }

    /// Noise value at `p`. Standard improved Perlin: hash the surrounding lattice cell's corners, dot each
    /// corner's pseudo-random gradient with the offset to `p`, and blend with the quintic fade.
    func value(at p: SIMD3<Float>) -> Float {
        let floored = p.rounded(.down)
        let cell = SIMD3<Int>(Int(floored.x) & 255, Int(floored.y) & 255, Int(floored.z) & 255)
        let f = p - floored
        let u = Self.fade(f.x), v = Self.fade(f.y), w = Self.fade(f.z)

        let a = table[cell.x] + cell.y
        let aa = table[a] + cell.z
        let ab = table[a + 1] + cell.z
        let b = table[cell.x + 1] + cell.y
        let ba = table[b] + cell.z
        let bb = table[b + 1] + cell.z

        return Self.lerp(w, Self.lerp(v, Self.lerp(u, Self.grad(table[aa], f.x, f.y, f.z),
                                                   Self.grad(table[ba], f.x - 1, f.y, f.z)),
                                      Self.lerp(u, Self.grad(table[ab], f.x, f.y - 1, f.z),
                                                Self.grad(table[bb], f.x - 1, f.y - 1, f.z))),
                         Self.lerp(v, Self.lerp(u, Self.grad(table[aa + 1], f.x, f.y, f.z - 1),
                                                Self.grad(table[ba + 1], f.x - 1, f.y, f.z - 1)),
                                   Self.lerp(u, Self.grad(table[ab + 1], f.x, f.y - 1, f.z - 1),
                                             Self.grad(table[bb + 1], f.x - 1, f.y - 1, f.z - 1))))
    }

    /// The quintic 6t⁵−15t⁴+10t³, zero first and second derivative at the lattice points.
    private static func fade(_ t: Float) -> Float {
        t * t * t * (t * (t * 6 - 15) + 10)
    }

    private static func lerp(_ t: Float, _ a: Float, _ b: Float) -> Float {
        a + t * (b - a)
    }

    /// Dot of the offset with one of the 12 edge-vector gradients, selected by the corner's hash.
    private static func grad(_ hash: Int, _ x: Float, _ y: Float, _ z: Float) -> Float {
        let h = hash & 15
        let u = h < 8 ? x : y
        let v = h < 4 ? y : (h == 12 || h == 14 ? x : z)
        return ((h & 1) == 0 ? u : -u) + ((h & 2) == 0 ? v : -v)
    }
}

/// Tiny seeded LCG so the star field is stable across renders without depending on a global RNG. From Knuth's generator
/// for MMIX (The Art of Computer Programming, volume 2, chapter 3). Walks all `2 ** 64` values before repeating.
struct SeededGenerator: RandomNumberGenerator {
    private var state: UInt64
    init(seed: UInt64) {
        self.state = seed
    }

    mutating func next() -> UInt64 {
        state = state &* 6_364_136_223_846_793_005 &+ 1_442_695_040_888_963_407
        return state
    }
}
