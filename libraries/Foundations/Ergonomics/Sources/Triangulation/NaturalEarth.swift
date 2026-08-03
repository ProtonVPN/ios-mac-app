//
//  Created on 30.06.2026 by John Biggs.
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
import simd

/// The Natural Earth pseudo-cylindrical projection (Bojan Savric et al.), the projection the source world map is drawn
/// in. The single home for its two polynomials and their inverse. The app's forward pin placement and the baker's
/// inverse un-projection both go through these coefficients, which together decide where every pin and every coastline
/// vertex lands, so they must not diverge.
///
/// Works in the projection's own normalised space: `project` returns `(x, y)` spanning plus or minus `halfWidth` and
/// `halfHeight`, and `unproject` inverts it. Map-specific framing, the pixel scale and the source map's shifted prime
/// meridian, is layered on by the callers, not baked in here.
public enum NaturalEarth {
    // The two half-extents are the polynomials evaluated at the domain edges, rounded at the 6th digit: halfWidth =
    // L(0) * pi = 2.7353847..., halfHeight = D(pi/2) = 1.4223905.... They are deliberately frozen transcriptions rather
    // than derived expressions, because the baker scales the source map through them and even a 5e-6 change re-bakes
    // every vertex in `world-globe.bin`. `NaturalEarthTests` pins them to the polynomial endpoints instead, which is
    // what guards the transcription. x half-extent of the projection at the equator and 180 degrees longitude (the
    // map's reference scale).
    public static let halfWidth = 2.73539
    /// y half-extent of the projection at the poles.
    public static let halfHeight = 1.42239

    /// Projects a geographic coordinate into Natural Earth `(x, y)` space.
    public static func project(_ coordinate: GeographicCoordinate) -> SIMD2<Double> {
        let phi = coordinate.latitude.radians
        let lambda = coordinate.longitude.radians
        return SIMD2<Double>(LengthOfParallel.standard(phi) * lambda, DistanceFromEquator.standard(phi))
    }

    /// Recovers the geographic coordinate of a point in Natural Earth `(x, y)` space, the inverse of `project`.
    /// Latitude comes from bisecting the monotonic distance-from-equator polynomial, and longitude then divides out the
    /// length of the parallel at that latitude.
    public static func unproject(_ point: SIMD2<Double>) -> GeographicCoordinate {
        var lo = -Double.pi / 2
        var hi = Double.pi / 2
        for _ in 0 ..< Constants.latitudeBisectionSteps {
            let mid = (lo + hi) / 2
            if DistanceFromEquator.standard(mid) < point.y { lo = mid } else { hi = mid }
        }
        let phi = (lo + hi) / 2
        let parallel = LengthOfParallel.standard(phi)
        let lambda = abs(parallel) > Constants.degenerateParallel ? point.x / parallel : 0
        return GeographicCoordinate(latitude: .radians(phi), longitude: .radians(lambda))
    }

    private enum Constants {
        /// Bisection steps inverting the monotonic latitude polynomial. Each step halves the interval, so around 50
        /// exhausts a `Double`'s 52-bit mantissa and past that the result no longer changes.
        static let latitudeBisectionSteps = 50
        /// Division guard on the parallel length. Effectively unreachable: Natural Earth has a pole line, so the
        /// parallel length stays above about 0.269 over the whole valid domain. This only matters for wildly
        /// out-of-range inputs.
        static let degenerateParallel = 1e-12
    }
}

/// Natural Earth's "length of a parallel" L(phi): the map's width at latitude phi as a fraction of the equator, an even
/// polynomial in phi (radians). The x of a coordinate is L(phi) times the longitude. Named coefficients, one per power
/// of phi, instead of a bare array, so the transcription can be checked term by term against the source.
struct LengthOfParallel {
    let c0, c2, c4, c10, c12: Double

    func callAsFunction(_ phi: Double) -> Double {
        c0 + c2 * pow(phi, 2) + c4 * pow(phi, 4) + c10 * pow(phi, 10) + c12 * pow(phi, 12)
    }

    static let standard = LengthOfParallel(c0: 0.8707, c2: -0.131979, c4: -0.013791, c10: 0.003971, c12: -0.001529)
}

/// Natural Earth's "distance from the equator" D(phi): the y of latitude phi, which is phi times an even polynomial in
/// phi (radians). Monotonic, which is what lets `unproject` invert it by bisection.
struct DistanceFromEquator {
    let c0, c2, c6, c8, c10: Double

    func callAsFunction(_ phi: Double) -> Double {
        (c0 + c2 * pow(phi, 2) + c6 * pow(phi, 6) + c8 * pow(phi, 8) + c10 * pow(phi, 10)) * phi
    }

    static let standard = DistanceFromEquator(c0: 1.007226, c2: 0.015085, c6: -0.044475, c8: 0.028874, c10: -0.005916)
}
