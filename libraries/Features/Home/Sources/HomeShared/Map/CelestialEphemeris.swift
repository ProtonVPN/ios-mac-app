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

/// Geocentric Sun and Moon positions as model-space directions on the globe — the *sub-solar* and
/// *sub-lunar* points (the body directly overhead) — plus the Moon's centre-to-centre distance in Earth
/// radii. Drives the day/night terminator, the Moon's phase + sky position, and the eclipse geometry.
///
/// An abridged Meeus (ELP-2000) lunar series — the dominant ~15–18 periodic terms — plus the standard solar
/// series. Good to roughly an arcminute, which is enough that solar/lunar eclipses fall on their real dates
/// (the Moon moves ~0.5°/h, so an arcminute is a couple of minutes of time). UTC is taken as TT — the ~70 s
/// ΔT is well below this precision.
enum CelestialEphemeris {
    struct Positions {
        /// Sub-solar point — model-space unit vector (Sun directly overhead).
        let sunDirection: SIMD3<Float>
        /// Sub-lunar point — model-space unit vector (Moon directly overhead).
        let moonDirection: SIMD3<Float>
        /// Earth-centre to Moon-centre distance, in Earth radii.
        let moonDistance: Float
    }

    /// One periodic term: amplitude (longitude/latitude in 1e-6°, distance in 1e-3 km) times the integer
    /// multipliers of the four fundamental arguments (elongation D, Sun anomaly M, Moon anomaly M′, latitude
    /// argument F). Summed with `sin` for longitude/latitude, `cos` for distance.
    private struct Term { let amp, d, m, mp, f: Double }

    private static let longitudeTerms: [Term] = [
        Term(amp: 6_288_774, d: 0, m: 0, mp: 1, f: 0),
        Term(amp: 1_274_027, d: 2, m: 0, mp: -1, f: 0),
        Term(amp: 658_314, d: 2, m: 0, mp: 0, f: 0),
        Term(amp: 213_618, d: 0, m: 0, mp: 2, f: 0),
        Term(amp: -185_116, d: 0, m: 1, mp: 0, f: 0),
        Term(amp: -114_332, d: 0, m: 0, mp: 0, f: 2),
        Term(amp: 58793, d: 2, m: 0, mp: -2, f: 0),
        Term(amp: 57066, d: 2, m: -1, mp: -1, f: 0),
        Term(amp: 53322, d: 2, m: 0, mp: 1, f: 0),
        Term(amp: 45758, d: 2, m: -1, mp: 0, f: 0),
        Term(amp: -40923, d: 0, m: 1, mp: -1, f: 0),
        Term(amp: -34720, d: 1, m: 0, mp: 0, f: 0),
        Term(amp: -30383, d: 0, m: 1, mp: 1, f: 0),
        Term(amp: 15327, d: 2, m: 0, mp: 0, f: -2),
        Term(amp: -12528, d: 0, m: 0, mp: 1, f: 2),
        Term(amp: 10980, d: 0, m: 0, mp: 1, f: -2),
        Term(amp: 10675, d: 4, m: 0, mp: -1, f: 0),
        Term(amp: 10034, d: 0, m: 0, mp: 3, f: 0),
    ]
    private static let latitudeTerms: [Term] = [
        Term(amp: 5_128_122, d: 0, m: 0, mp: 0, f: 1),
        Term(amp: 280_602, d: 0, m: 0, mp: 1, f: 1),
        Term(amp: 277_693, d: 0, m: 0, mp: 1, f: -1),
        Term(amp: 173_237, d: 2, m: 0, mp: 0, f: -1),
        Term(amp: 55413, d: 2, m: 0, mp: -1, f: 1),
        Term(amp: 46271, d: 2, m: 0, mp: -1, f: -1),
        Term(amp: 32573, d: 2, m: 0, mp: 0, f: 1),
        Term(amp: 17198, d: 0, m: 0, mp: 2, f: 1),
        Term(amp: 9266, d: 2, m: 0, mp: 1, f: -1),
        Term(amp: 8822, d: 0, m: 0, mp: 2, f: -1),
        Term(amp: 8216, d: 2, m: -1, mp: 0, f: -1),
        Term(amp: 4324, d: 2, m: 0, mp: -2, f: -1),
        Term(amp: 4200, d: 2, m: 0, mp: 1, f: 1),
    ]
    private static let distanceTerms: [Term] = [
        Term(amp: -20_905_355, d: 0, m: 0, mp: 1, f: 0),
        Term(amp: -3_699_111, d: 2, m: 0, mp: -1, f: 0),
        Term(amp: -2_955_968, d: 2, m: 0, mp: 0, f: 0),
        Term(amp: -569_925, d: 0, m: 0, mp: 2, f: 0),
        Term(amp: 246_158, d: 2, m: 0, mp: -2, f: 0),
        Term(amp: -204_586, d: 2, m: -1, mp: 0, f: 0),
        Term(amp: -170_733, d: 2, m: 0, mp: 1, f: 0),
        Term(amp: -152_138, d: 2, m: -1, mp: -1, f: 0),
        Term(amp: -129_620, d: 0, m: 1, mp: -1, f: 0),
        Term(amp: 108_743, d: 1, m: 0, mp: 0, f: 0),
        Term(amp: 104_755, d: 0, m: 1, mp: 1, f: 0),
    ]

    static func positions(at date: Date) -> Positions {
        let rad = Double.pi / 180
        let jd = date.timeIntervalSince1970 / 86400 + 2_440_587.5
        let t = (jd - 2_451_545.0) / 36525 // Julian centuries from J2000

        // Fundamental arguments (degrees).
        let lp = 218.3164477 + 481_267.88123421 * t - 0.0015786 * t * t // Moon mean longitude
        let d = 297.8501921 + 445_267.1114034 * t - 0.0018819 * t * t // mean elongation Moon–Sun
        let m = 357.5291092 + 35999.0502909 * t - 0.0001536 * t * t // Sun mean anomaly
        let mp = 134.9633964 + 477_198.8675055 * t + 0.0087414 * t * t // Moon mean anomaly
        let f = 93.2720950 + 483_202.0175233 * t - 0.0036539 * t * t // argument of latitude

        func sum(_ terms: [Term], _ trig: (Double) -> Double) -> Double {
            terms.reduce(0) { $0 + $1.amp * trig(($1.d * d + $1.m * m + $1.mp * mp + $1.f * f) * rad) }
        }
        let moonLon = lp + sum(longitudeTerms, sin) / 1_000_000
        let moonLat = sum(latitudeTerms, sin) / 1_000_000
        let moonDeltaKm = 385_000.56 + sum(distanceTerms, cos) / 1000

        // Sun (Meeus ch.25): mean longitude + equation of centre → true ecliptic longitude (latitude ≈ 0).
        let l0 = 280.46646 + 36000.76983 * t + 0.0003032 * t * t
        let c = (1.914602 - 0.004817 * t) * sin(m * rad)
            + (0.019993 - 0.000101 * t) * sin(2 * m * rad)
            + 0.000289 * sin(3 * m * rad)
        let sunLon = l0 + c

        let eps = 23.439291 - 0.0130042 * t // obliquity of the ecliptic
        // Greenwich mean sidereal time (degrees) — geographic longitude of the vernal equinox right now.
        let gmst = 280.46061837 + 360.98564736629 * (jd - 2_451_545.0) + 0.000387933 * t * t

        // Ecliptic → equatorial → the sub-point's geographic lat/lon. The body is overhead where the local
        // hour angle is zero, i.e. east longitude = right ascension − GMST. Normalised in Double before the
        // Float cast, since GMST is a huge number that would lose all precision as a Float.
        func subPoint(lonEcl: Double, latEcl: Double) -> (lat: Double, lon: Double) {
            let lam = lonEcl * rad, bet = latEcl * rad, e = eps * rad
            let ra = atan2(sin(lam) * cos(e) - tan(bet) * sin(e), cos(lam)) / rad
            let dec = asin(sin(bet) * cos(e) + cos(bet) * sin(e) * sin(lam)) / rad
            var lon = (ra - gmst).truncatingRemainder(dividingBy: 360)
            if lon > 180 { lon -= 360 } else if lon < -180 { lon += 360 }
            return (dec, lon)
        }
        let sun = subPoint(lonEcl: sunLon, latEcl: 0)
        let moon = subPoint(lonEcl: moonLon, latEcl: moonLat)

        return Positions(
            sunDirection: GlobeGeometry.unitSphere(latitudeDegrees: Float(sun.lat), longitudeDegrees: Float(sun.lon)),
            moonDirection: GlobeGeometry.unitSphere(latitudeDegrees: Float(moon.lat), longitudeDegrees: Float(moon.lon)),
            moonDistance: Float(moonDeltaKm / 6378.14)
        )
    }
}
