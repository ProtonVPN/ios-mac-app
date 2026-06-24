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

import Triangulation
import XCTest

/// Reference values and a round-trip for the Natural Earth projection. This is the single source of the
/// projection's polynomials, and the globe baker inverts it to place every coastline vertex, so these
/// assertions guard the maths the whole map depends on.
final class NaturalEarthTests: XCTestCase {
    private static let accuracy = 1e-5

    private func project(lat: Double, lon: Double) -> SIMD2<Double> {
        NaturalEarth.project(GeographicCoordinate(latitude: .degrees(lat), longitude: .degrees(lon)))
    }

    func testOrigin() {
        let p = project(lat: 0, lon: 0)
        XCTAssertEqual(p.x, 0)
        XCTAssertEqual(p.y, 0)
    }

    func testNorthPoleMapsToTopHalfHeight() {
        let p = project(lat: 90, lon: 0)
        XCTAssertEqual(p.y, NaturalEarth.halfHeight, accuracy: Self.accuracy)
        XCTAssertEqual(p.x, 0)
    }

    func testSouthPoleMapsToBottomHalfHeight() {
        let p = project(lat: -90, lon: 0)
        XCTAssertEqual(p.y, -NaturalEarth.halfHeight, accuracy: Self.accuracy)
        XCTAssertEqual(p.x, 0)
    }

    func testEastEdgeMapsToHalfWidth() {
        let p = project(lat: 0, lon: 180)
        XCTAssertEqual(p.x, NaturalEarth.halfWidth, accuracy: Self.accuracy)
        XCTAssertEqual(p.y, 0)
    }

    func testWestEdgeMapsToMinusHalfWidth() {
        let p = project(lat: 0, lon: -180)
        XCTAssertEqual(p.x, -NaturalEarth.halfWidth, accuracy: Self.accuracy)
        XCTAssertEqual(p.y, 0)
    }

    /// Unprojecting a projected point recovers it. This is the baker's inverse path, so it must round-trip
    /// tightly.
    func testProjectUnprojectRoundTrips() {
        for lat in stride(from: -85.0, through: 85.0, by: 17.0) {
            for lon in stride(from: -170.0, through: 170.0, by: 31.0) {
                let recovered = NaturalEarth.unproject(project(lat: lat, lon: lon))
                XCTAssertEqual(recovered.latitude.degrees, lat, accuracy: 1e-9)
                XCTAssertEqual(recovered.longitude.degrees, lon, accuracy: 1e-9)
            }
        }
    }
}
