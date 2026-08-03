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
import simd
import Testing
@testable import Triangulation

@Suite("Astronomy constants")
struct AstronomyTests {
    @Test("The galactic north pole is a unit vector at its published declination")
    func galacticPoleMatchesPublishedCoordinates() {
        let pole = CelestialConstants.galacticNorthPole

        #expect(abs(simd_length(pole) - 1) < 1e-5)
        // Declination is the y (latitude) component under the shared sphere convention.
        #expect(abs(asin(Double(pole.y)) * 180 / .pi - 27.12825) < 0.001)
    }

    @Test("The galactic pole is perpendicular to the galactic centre direction")
    func galacticPoleIsPerpendicularToGalacticCentre() {
        // Sagittarius A* (J2000: RA 266.41683°, Dec −29.00781°) lies in the galactic plane, so its direction — mapped
        // through the same convention — must be orthogonal to the pole. This cross-checks the pair against
        // independently published coordinates: an RA/longitude sign or axis mix-up would break the orthogonality
        // immediately.
        let pole = CelestialConstants.galacticNorthPole
        let centre = GlobeGeometry.unitSphere(latitudeDegrees: -29.00781, longitudeDegrees: 266.41683)

        #expect(abs(simd_dot(pole, centre)) < 0.002)
    }
}
