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

import Testing
import Triangulation

@Suite("Angle")
struct AngleTests {
    private let accuracy = 1e-12

    private func normalized(_ degrees: Double) -> Double {
        Angle.degrees(degrees).normalizedSigned.degrees
    }

    private func expectClose(
        _ value: Double,
        _ expected: Double,
        sourceLocation: SourceLocation = #_sourceLocation
    ) {
        #expect(
            abs(value - expected) < accuracy,
            "\(value) is not within \(accuracy) of \(expected)",
            sourceLocation: sourceLocation
        )
    }

    /// The documented interval is (-180, 180] degrees: the antimeridian has one normal form, +180,
    /// whichever side it's approached from, so equal meridians can't compare unequal after wrapping.
    @Test("normalizedSigned wraps into the half-open interval (-180, 180]")
    func normalizedSignedWrapsIntoHalfOpenInterval() {
        expectClose(normalized(0), 0)
        expectClose(normalized(180), 180)
        expectClose(normalized(-180), 180)
        expectClose(normalized(540), 180)
        expectClose(normalized(-540), 180)
        expectClose(normalized(190), -170)
        expectClose(normalized(-190), 170)
        expectClose(normalized(360), 0)
        expectClose(normalized(725), 5)
        expectClose(normalized(-725), -5)
    }

    @Test("Degrees and radians round-trip")
    func degreeRadianRoundTrip() {
        expectClose(Angle.degrees(90).radians, .pi / 2)
        expectClose(Angle.radians(.pi).degrees, 180)
    }

    /// `<` is a signed compare (minus 90 degrees is less than 45), not magnitude, which is what
    /// `max`-reducing non-negative cap radii relies on.
    @Test("Comparable is a signed compare, not magnitude")
    func comparableIsSignedNotMagnitude() {
        #expect(Angle.degrees(-90) < Angle.degrees(45))
        #expect(Angle.degrees(10) < Angle.degrees(20))
        #expect(!(Angle.degrees(45) < Angle.degrees(-90)))
    }
}
