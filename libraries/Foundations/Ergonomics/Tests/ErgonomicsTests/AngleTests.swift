//
//  Created on 02.07.2026 by John Biggs.
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

final class AngleTests: XCTestCase {
    private static let accuracy = 1e-12

    private func normalized(_ degrees: Double) -> Double {
        Angle.degrees(degrees).normalizedSigned.degrees
    }

    /// The documented interval is (-180, 180] degrees: the antimeridian has one normal form, +180,
    /// whichever side it's approached from, so equal meridians can't compare unequal after wrapping.
    func testNormalizedSignedWrapsIntoHalfOpenInterval() {
        XCTAssertEqual(normalized(0), 0, accuracy: Self.accuracy)
        XCTAssertEqual(normalized(180), 180, accuracy: Self.accuracy)
        XCTAssertEqual(normalized(-180), 180, accuracy: Self.accuracy)
        XCTAssertEqual(normalized(540), 180, accuracy: Self.accuracy)
        XCTAssertEqual(normalized(-540), 180, accuracy: Self.accuracy)
        XCTAssertEqual(normalized(190), -170, accuracy: Self.accuracy)
        XCTAssertEqual(normalized(-190), 170, accuracy: Self.accuracy)
        XCTAssertEqual(normalized(360), 0, accuracy: Self.accuracy)
        XCTAssertEqual(normalized(725), 5, accuracy: Self.accuracy)
        XCTAssertEqual(normalized(-725), -5, accuracy: Self.accuracy)
    }

    func testDegreeRadianRoundTrip() {
        XCTAssertEqual(Angle.degrees(90).radians, .pi / 2, accuracy: Self.accuracy)
        XCTAssertEqual(Angle.radians(.pi).degrees, 180, accuracy: Self.accuracy)
    }

    /// `<` is a signed compare (minus 90 degrees is less than 45), not magnitude, which is what
    /// `max`-reducing non-negative cap radii relies on.
    func testComparableIsSignedNotMagnitude() {
        XCTAssertLessThan(Angle.degrees(-90), Angle.degrees(45))
        XCTAssertLessThan(Angle.degrees(10), Angle.degrees(20))
        XCTAssertFalse(Angle.degrees(45) < Angle.degrees(-90))
    }
}
