//
//  Created on 20/08/2026.
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
import Testing
import Triangulation

@Suite("Spherical cap")
struct SphericalCapTests {
    @Test("Rim points sit on the rim, evenly spaced, starting poleward")
    func rimPointsSitOnRim() {
        let cap = SphericalCap(
            center: GlobeGeometry.unitSphere(latitudeDegrees: 40, longitudeDegrees: -100),
            radius: .degrees(26)
        )
        let rim = cap.rim(count: 8)

        #expect(rim.count == 8)
        for point in rim {
            #expect(abs(simd_length(point) - 1) < 1e-4, "rim points stay on the unit sphere")
            #expect(abs(angle(between: cap.center, point).degrees - 26) < 0.01, "rim points sit at the cap radius")
        }
        // Evenly spaced: each neighbor pair subtends the same angle around the ring.
        let steps = (0 ..< rim.count).map { angle(between: rim[$0], rim[($0 + 1) % rim.count]).degrees }
        for step in steps {
            #expect(abs(step - steps[0]) < 0.01)
        }
        // The ring starts at the northernmost rim point: latitude of the center plus the radius.
        let first = GlobeGeometry.coordinate(of: rim[0])
        #expect(abs(first.latitude.degrees - 66) < 0.01)
    }

    @Test("A zero cap's rim is its center, and a polar cap still yields a ring")
    func degenerateAndPolarRims() {
        let point = SphericalCap(
            center: GlobeGeometry.unitSphere(latitudeDegrees: 10, longitudeDegrees: 10),
            radius: .radians(0)
        )
        #expect(point.rim(count: 4) == Array(repeating: point.center, count: 4))
        #expect(point.rim(count: 0).isEmpty)

        let polar = SphericalCap(center: SIMD3<Float>(0, 1, 0), radius: .degrees(10))
        for rimPoint in polar.rim(count: 6) {
            #expect(abs(angle(between: polar.center, rimPoint).degrees - 10) < 0.01)
        }
    }
}
