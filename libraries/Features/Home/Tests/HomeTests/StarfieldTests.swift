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
@testable import HomeShared
import MapShaderTypes
import simd
import Testing
import Triangulation

@Suite("Starfield")
struct StarfieldTests {
    /// Half-width of the measurement band as sin(galactic latitude). The sphere's area fraction within
    /// |sin latitude| < s is exactly s, which is what normalizes the density ratio below.
    private let bandSin: Float = 0.25

    /// In-band over out-of-band star density, each normalized by the solid angle it covers.
    private func bandDensityRatio(of field: [StarInstance]) -> Float {
        let pole = CelestialConstants.galacticNorthPole
        let inBand = field.count { abs(simd_dot($0.direction, pole)) < bandSin }
        let outOfBand = field.count - inBand
        return (Float(inBand) / bandSin) / (Float(outOfBand) / (1 - bandSin))
    }

    @Test("The same seed reproduces the same field, star for star")
    func fieldIsDeterministic() {
        let first = Starfield.instances(seed: 42, count: 300, bandStrength: 0.8)
        let second = Starfield.instances(seed: 42, count: 300, bandStrength: 0.8)

        #expect(first.count == 300)
        let identical = zip(first, second).allSatisfy {
            $0.direction == $1.direction && $0.radius == $1.radius && $0.brightness == $1.brightness
        }
        #expect(identical)
    }

    @Test("Every star sits on the unit sphere with attributes in range")
    func starsAreWellFormed() {
        // The field is now pinpoint stars only; the Milky Way's diffuse body is the renderer's analytic
        // sky-glow pass (`fragment_skyglow`), validated by the A/B snapshot rather than here.
        for star in Starfield.instances {
            #expect(abs(simd_length(star.direction) - 1) < 1e-4)
            #expect(Starfield.Constants.radiusRange.contains(star.radius))
            #expect(star.brightness > 0 && star.brightness <= 1)
        }
    }

    @Test("The shipped field is at least twice as dense along the galactic plane")
    func shippedFieldCarriesTheMilkyWayBand() {
        // Deterministic with the fixed seed, so this is an exact contract, not a statistical bet.
        #expect(bandDensityRatio(of: Starfield.instances) > 2)
    }

    @Test("Zero band strength produces a roughly uniform sky")
    func zeroBandStrengthIsUniform() {
        let uniform = Starfield.instances(seed: 42, count: 600, bandStrength: 0)
        let ratio = bandDensityRatio(of: uniform)
        // Finite-sample wobble only; the band term is off.
        #expect(ratio > 0.7 && ratio < 1.4)
    }

    @Test("Star opacity ramps from nothing at the whole-globe distance to full at the ceiling")
    func opacityRamp() {
        // The real ceiling the view passes, not a copied literal, so a zoom-limit change moves this test.
        let ceiling = GlobeTrackballModel.maxZoomDistance
        #expect(Starfield.opacity(atDistance: GlobeFocus.wholeGlobeDistance, ceiling: ceiling) == 0)
        #expect(Starfield.opacity(atDistance: ceiling, ceiling: ceiling) == 1)
        let midway = (GlobeFocus.wholeGlobeDistance + ceiling) / 2
        let mid = Starfield.opacity(atDistance: midway, ceiling: ceiling)
        #expect(mid > 0 && mid < 1)
    }
}
