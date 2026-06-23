//
//  Created on 23/06/2026.
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
import MapModel
import simd

/// Where the sun is over the Earth right now, as a model-space unit direction on the globe — the subsolar
/// point (sun directly overhead). Used to light the globe with the real day/night terminator and to place
/// the sun in the sky. Low-precision astronomy (no equation of time / nutation), good to ~1–2°, which is
/// plenty for a stylised globe.
enum SunPosition {
    static func subsolarDirection(at date: Date) -> SIMD3<Float> {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "UTC") ?? .gmt
        let dayOfYear = Float(calendar.ordinality(of: .day, in: .year, for: date) ?? 1)
        // UTC hour-of-day with fraction (epoch is UTC midnight, so seconds/3600 mod 24 is the UTC hour).
        let utcHour = Float((date.timeIntervalSince1970 / 3600).truncatingRemainder(dividingBy: 24))
        // Solar declination = subsolar latitude (simple cosine model: +23.44° at the June solstice).
        let declination = -23.44 * cos((2 * .pi / 365.24) * (dayOfYear + 10))
        // Subsolar longitude: the sun is over the Greenwich meridian near 12:00 UTC and tracks west 15°/h.
        let longitude = -15 * (utcHour - 12)
        return GlobeGeometry.unitSphere(latitudeDegrees: declination, longitudeDegrees: longitude)
    }
}
