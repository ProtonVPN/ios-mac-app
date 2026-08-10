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

import Ergonomics
import Foundation
@testable import HomeShared
import MapModel
import simd
import Testing
import Triangulation

/// `CoastSnap.snap`'s contract, on a synthetic one-triangle "country" so no baked resources are involved: a point on
/// the land stays put, a point just offshore snaps to the nearest point of the land's boundary, and a point farther
/// than `maxSnapAngle` is left put, the check against wrong geometry. Both the gray city pins and the
/// user/connection pin place themselves with this rule.
@Suite("Coast snapping")
struct CoastSnapTests {
    /// One spherical triangle of "land" near the origin, two degrees on a side, wound counter-clockwise seen from
    /// outside the sphere, as the baker guarantees.
    private static let a = GlobeGeometry.unitSphere(latitudeDegrees: 0, longitudeDegrees: 0)
    private static let b = GlobeGeometry.unitSphere(latitudeDegrees: 0, longitudeDegrees: 2)
    private static let c = GlobeGeometry.unitSphere(latitudeDegrees: 2, longitudeDegrees: 0)

    private static let country = MapGlobeCountry(
        cap: SphericalCap(center: simd_normalize(a + b + c), radius: .degrees(3)),
        pin: simd_normalize(a + b + c),
        fillRanges: [0 ..< 3],
        borderRanges: []
    )

    private static let model = MapGlobeModel<InMemory>(
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
        #expect(Self.model.withMesh { CoastSnap.snap(direction, to: Self.country, in: $0) } == direction)
    }

    @Test("A point just offshore snaps past the nearest vertex, landing on the country's fill")
    func justOffshoreSnapsOntoLand() {
        // About 1.41 degrees from the origin vertex: within `maxSnapAngle`, and nearer to that vertex than to the
        // others. The snap must not stop at the vertex, since a pin centered on the coastline still reads as offshore.
        // It carries the point inland, verifiably inside the triangle.
        let direction = GlobeGeometry.unitSphere(latitudeDegrees: -1, longitudeDegrees: -1)
        let snapped = Self.model.withMesh { CoastSnap.snap(direction, to: Self.country, in: $0) }
        #expect(snapped != direction)
        #expect(SphericalTriangle(Self.a, Self.b, Self.c).contains(snapped))
        #expect(angle(between: Self.a, snapped).degrees <= CoastSnap.inlandNudge.degrees + 0.01)
    }

    @Test("A point farther than the snap limit is left put, not flung onto the land")
    func farAwayIsLeftPut() {
        let direction = GlobeGeometry.unitSphere(latitudeDegrees: 10, longitudeDegrees: 10)
        #expect(Self.model.withMesh { CoastSnap.snap(direction, to: Self.country, in: $0) } == direction)
    }

    @Test("A point offshore of an edge's middle snaps onto the edge, not to a distant vertex")
    func offshoreOfAnEdgeSnapsOntoTheEdge() {
        // Due west of the a-c edge's midpoint: the nearest boundary point is on the edge's interior, a degree from
        // either vertex. A vertex snap would carry the pin that full degree along the coast. The edge snap keeps
        // it level with where it approached.
        let direction = GlobeGeometry.unitSphere(latitudeDegrees: 1, longitudeDegrees: -1)
        let snapped = Self.model.withMesh { CoastSnap.snap(direction, to: Self.country, in: $0) }
        #expect(SphericalTriangle(Self.a, Self.b, Self.c).contains(snapped))
        let landing = GlobeGeometry.coordinate(of: snapped)
        #expect(abs(landing.latitude.degrees - 1) < 0.05)
    }

    @Test("A pin a hair offshore is corrected by a hair, not by the full inland nudge")
    func slightlyOffshoreMovesSlightly() {
        // A twentieth of a degree off the southern edge. The nudge is bounded by half the snap distance, so the
        // total correction stays about that size instead of the fixed fifth of a degree.
        let direction = GlobeGeometry.unitSphere(latitudeDegrees: -0.05, longitudeDegrees: 0.5)
        let snapped = Self.model.withMesh { CoastSnap.snap(direction, to: Self.country, in: $0) }
        #expect(snapped != direction)
        #expect(SphericalTriangle(Self.a, Self.b, Self.c).contains(snapped))
        #expect(angle(between: direction, snapped).degrees < 0.1)
    }

    @Test("A point deep inside a very wide triangle is still on its land")
    func wideTriangleStillHoldsItsInterior() {
        // `robustlyContains` accepts a point only within twice the triangle's widest side of its first vertex.
        // Past a side of ninety degrees, twice the side covers the whole sphere, but the cosine the bound is
        // computed in rises again and would exclude points the triangle holds. This triangle's widest side is
        // 150 degrees, and the point sits 76 degrees from the first vertex: inside the triangle, and outside the
        // 60 degrees the rising cosine would otherwise allow.
        let a = GlobeGeometry.unitSphere(latitudeDegrees: 0, longitudeDegrees: 0)
        let b = GlobeGeometry.unitSphere(latitudeDegrees: 0, longitudeDegrees: 150)
        let c = GlobeGeometry.unitSphere(latitudeDegrees: 75, longitudeDegrees: 75)
        let hemisphere = MapGlobeCountry(
            cap: SphericalCap(center: simd_normalize(a + b + c), radius: .degrees(90)),
            pin: simd_normalize(a + b + c),
            fillRanges: [0 ..< 3],
            borderRanges: []
        )
        let model = MapGlobeModel<InMemory>(
            fillVertices: [a, b, c],
            fillIndices: [0, 1, 2],
            borderSegments: [],
            borderColor: .zero,
            drawOrder: [],
            countries: ["xx": hemisphere]
        )

        let direction = GlobeGeometry.unitSphere(latitudeDegrees: 20, longitudeDegrees: 75)
        #expect(SphericalTriangle(a, b, c).contains(direction))
        #expect(model.withMesh { CoastSnap.snap(direction, to: hemisphere, in: $0) } == direction)
    }

    @Test("A degenerate (weld-collapsed) triangle can't make the whole ocean read as land")
    func degenerateTriangleDoesNotSwallowTheOcean() {
        // A duplicate vertex zeroes an edge normal, and a raw sign test would then hold for every point on the sphere,
        // letting one bad sliver disable coast snapping for its whole country. With the degenerate triangle listed
        // first, the offshore point must still snap onto the real land.
        let degenerate = MapGlobeModel<InMemory>(
            fillVertices: [Self.a, Self.b, Self.c],
            fillIndices: [0, 0, 2, 0, 1, 2], // the degenerate (a, a, c), then the real triangle
            borderSegments: [],
            borderColor: .zero,
            drawOrder: [],
            countries: ["xx": Self.degenerateCountry]
        )
        let direction = GlobeGeometry.unitSphere(latitudeDegrees: -1, longitudeDegrees: -1)
        let snapped = degenerate.withMesh { CoastSnap.snap(direction, to: Self.degenerateCountry, in: $0) }
        #expect(snapped != direction)
        #expect(SphericalTriangle(Self.a, Self.b, Self.c).contains(snapped))
    }

    private static let degenerateCountry = MapGlobeCountry(
        cap: SphericalCap(center: simd_normalize(a + b + c), radius: .degrees(3)),
        pin: simd_normalize(a + b + c),
        fillRanges: [0 ..< 6],
        borderRanges: []
    )
}
