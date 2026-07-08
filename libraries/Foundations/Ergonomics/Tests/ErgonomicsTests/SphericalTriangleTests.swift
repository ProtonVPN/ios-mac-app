//
//  Created on 03.07.2026 by John Biggs.
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

@Suite("Spherical triangle")
struct SphericalTriangleTests {
    private let a = GlobeGeometry.unitSphere(latitudeDegrees: 0, longitudeDegrees: 0)
    private let b = GlobeGeometry.unitSphere(latitudeDegrees: 0, longitudeDegrees: 2)
    private let c = GlobeGeometry.unitSphere(latitudeDegrees: 2, longitudeDegrees: 0)

    @Test("Contains an interior point regardless of winding")
    func containsInteriorPointEitherWinding() {
        let inside = GlobeGeometry.unitSphere(latitudeDegrees: 0.5, longitudeDegrees: 0.5)
        #expect(SphericalTriangle(a, b, c).contains(inside))
        #expect(SphericalTriangle(a, c, b).contains(inside), "containment is winding-independent")
    }

    @Test("Does not contain an outside point")
    func doesNotContainOutsidePoint() {
        let outside = GlobeGeometry.unitSphere(latitudeDegrees: -0.5, longitudeDegrees: -0.5)
        #expect(!SphericalTriangle(a, b, c).contains(outside))
    }

    /// A duplicate vertex zeroes an edge normal, and a raw sign test would then hold (`0 >= 0`) for every
    /// point on the sphere, making one weld-collapsed sliver in a country's mesh claim the whole ocean as
    /// land. A degenerate triangle must contain nothing.
    @Test("A degenerate triangle contains nothing")
    func degenerateTriangleContainsNothing() {
        let degenerate = SphericalTriangle(a, a, c)
        #expect(!degenerate.contains(a))
        #expect(!degenerate.contains(GlobeGeometry.unitSphere(latitudeDegrees: 0.5, longitudeDegrees: 0.5)))
        #expect(!degenerate.contains(GlobeGeometry.unitSphere(latitudeDegrees: -40, longitudeDegrees: 60)))

        let collinear = SphericalTriangle(
            GlobeGeometry.unitSphere(latitudeDegrees: 0, longitudeDegrees: 0),
            GlobeGeometry.unitSphere(latitudeDegrees: 0, longitudeDegrees: 1),
            GlobeGeometry.unitSphere(latitudeDegrees: 0, longitudeDegrees: 2)
        )
        #expect(!collinear.contains(GlobeGeometry.unitSphere(latitudeDegrees: 20, longitudeDegrees: 1)))
    }
}
