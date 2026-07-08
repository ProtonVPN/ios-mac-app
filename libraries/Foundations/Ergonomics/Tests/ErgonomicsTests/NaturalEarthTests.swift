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

import Testing
import Triangulation

/// Reference values and a round-trip for the Natural Earth projection. This is the single source of the
/// projection's polynomials, and the globe baker inverts it to place every coastline vertex, so these
/// assertions guard the maths the whole map depends on.
@Suite("Natural Earth projection")
struct NaturalEarthTests {
    private let accuracy = 1e-5

    private func project(lat: Double, lon: Double) -> SIMD2<Double> {
        NaturalEarth.project(GeographicCoordinate(latitude: .degrees(lat), longitude: .degrees(lon)))
    }

    private func expectClose(
        _ value: Double,
        _ expected: Double,
        tolerance: Double? = nil,
        sourceLocation: SourceLocation = #_sourceLocation
    ) {
        let tolerance = tolerance ?? accuracy
        #expect(
            abs(value - expected) < tolerance,
            "\(value) is not within \(tolerance) of \(expected)",
            sourceLocation: sourceLocation
        )
    }

    @Test("Origin projects to zero")
    func origin() {
        let p = project(lat: 0, lon: 0)
        #expect(p.x == 0)
        #expect(p.y == 0)
    }

    @Test("North pole maps to +halfHeight")
    func northPoleMapsToTopHalfHeight() {
        let p = project(lat: 90, lon: 0)
        expectClose(p.y, NaturalEarth.halfHeight)
        #expect(p.x == 0)
    }

    @Test("South pole maps to -halfHeight")
    func southPoleMapsToBottomHalfHeight() {
        let p = project(lat: -90, lon: 0)
        expectClose(p.y, -NaturalEarth.halfHeight)
        #expect(p.x == 0)
    }

    @Test("East edge maps to +halfWidth")
    func eastEdgeMapsToHalfWidth() {
        let p = project(lat: 0, lon: 180)
        expectClose(p.x, NaturalEarth.halfWidth)
        #expect(p.y == 0)
    }

    @Test("West edge maps to -halfWidth")
    func westEdgeMapsToMinusHalfWidth() {
        let p = project(lat: 0, lon: -180)
        expectClose(p.x, -NaturalEarth.halfWidth)
        #expect(p.y == 0)
    }

    /// Unprojecting a projected point recovers it. This is the baker's inverse path, so it must round-trip
    /// tightly.
    @Test("Project and unproject round-trip")
    func projectUnprojectRoundTrips() {
        for lat in stride(from: -85.0, through: 85.0, by: 17.0) {
            for lon in stride(from: -170.0, through: 170.0, by: 31.0) {
                let recovered = NaturalEarth.unproject(project(lat: lat, lon: lon))
                expectClose(recovered.latitude.degrees, lat, tolerance: 1e-9)
                expectClose(recovered.longitude.degrees, lon, tolerance: 1e-9)
            }
        }
    }
}
