//
//  Created on 02/07/2026.
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
import MapModel
import simd
import Testing
import Triangulation

/// `CoastSnap.snap`'s contract, on a synthetic one-triangle "country" so no baked resources are involved:
/// a point on the land stays put, a point just offshore snaps to the nearest land vertex, and a point
/// farther than `maxSnapAngle` is left put, the guard against wrong geometry. This is the placement rule
/// both the grey city pins and the user/connection pin render through.
@Suite("Coast snapping")
struct CoastSnapTests {
    /// One spherical triangle of "land" near the origin, two degrees on a side, wound counter-clockwise
    /// seen from outside the sphere, as the baker guarantees.
    private static let a = GlobeGeometry.unitSphere(latitudeDegrees: 0, longitudeDegrees: 0)
    private static let b = GlobeGeometry.unitSphere(latitudeDegrees: 0, longitudeDegrees: 2)
    private static let c = GlobeGeometry.unitSphere(latitudeDegrees: 2, longitudeDegrees: 0)

    private static let country = MapGlobeCountry(
        cap: SphericalCap(center: simd_normalize(a + b + c), radius: .degrees(3)),
        fillRanges: [0 ..< 3],
        borderRanges: []
    )

    private static let model = MapGlobeModel(
        fillVertices: [a, b, c],
        fillIndices: [0, 1, 2],
        borderSegments: [],
        borderColor: .zero,
        drawOrder: [],
        countries: ["xx": country]
    )

    @Test("A point on the country's land is left exactly where it is")
    func onLandStaysPut() {
        let direction = GlobeGeometry.unitSphere(latitudeDegrees: 0.5, longitudeDegrees: 0.5)
        #expect(CoastSnap.snap(direction, to: Self.country, in: Self.model) == direction)
    }

    @Test("A point just offshore snaps past the nearest vertex, landing on the country's fill")
    func justOffshoreSnapsOntoLand() {
        // About 1.41 degrees from the origin vertex: inside the 1.5-degree snap cap and nearer to it than
        // to the others. The snap must not stop at the vertex, since a pin centred on the coastline still
        // reads as offshore. It carries the point inland, verifiably inside the triangle.
        let direction = GlobeGeometry.unitSphere(latitudeDegrees: -1, longitudeDegrees: -1)
        let snapped = CoastSnap.snap(direction, to: Self.country, in: Self.model)
        #expect(snapped != direction)
        #expect(SphericalTriangle(Self.a, Self.b, Self.c).contains(snapped))
        #expect(angle(between: Self.a, snapped).degrees <= CoastSnap.inlandNudge.degrees + 0.01)
    }

    @Test("A point farther than the snap cap is left put, not flung onto the land")
    func farAwayIsLeftPut() {
        let direction = GlobeGeometry.unitSphere(latitudeDegrees: 10, longitudeDegrees: 10)
        #expect(CoastSnap.snap(direction, to: Self.country, in: Self.model) == direction)
    }

    @Test("A degenerate (weld-collapsed) triangle can't make the whole ocean read as land")
    func degenerateTriangleDoesNotSwallowTheOcean() {
        // A duplicate vertex zeroes an edge normal, and a raw sign test would then hold for every point on
        // the sphere, letting one bad sliver disable coast snapping for its whole country. With the
        // degenerate triangle listed first, the offshore point must still snap onto the real land.
        let degenerate = MapGlobeModel(
            fillVertices: [Self.a, Self.b, Self.c],
            fillIndices: [0, 0, 2, 0, 1, 2], // the degenerate (a, a, c), then the real triangle
            borderSegments: [],
            borderColor: .zero,
            drawOrder: [],
            countries: ["xx": Self.degenerateCountry]
        )
        let direction = GlobeGeometry.unitSphere(latitudeDegrees: -1, longitudeDegrees: -1)
        let snapped = CoastSnap.snap(direction, to: Self.degenerateCountry, in: degenerate)
        #expect(snapped != direction)
        #expect(SphericalTriangle(Self.a, Self.b, Self.c).contains(snapped))
    }

    private static let degenerateCountry = MapGlobeCountry(
        cap: SphericalCap(center: simd_normalize(a + b + c), radius: .degrees(3)),
        fillRanges: [0 ..< 6],
        borderRanges: []
    )
}
