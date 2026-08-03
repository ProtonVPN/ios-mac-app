//
//  Created on 29.06.2026 by John Biggs.
//
//  Copyright (c) 2026 Proton AG
//
//  Proton VPN is free software: you can redistribute it and/or modify
//  it under the terms of the GNU General Public License as published by
//  the Free Software Foundation, either version 3 of the License, or
//  (at your option) any later version.
//
//  Proton VPN is distributed in the hope that it will be useful,
//  but WITHOUT ANY WARRANTY; without even the implied warranty of
//  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
//  GNU General Public License for more details.
//
//  You should have received a copy of the GNU General Public License
//  along with Proton VPN.  If not, see <https://www.gnu.org/licenses/>.

import Foundation
import simd

// MARK: - Time

/// An absolute instant expressed as a Julian Date, owning the epoch offsets the Meeus series are built on. Foundation
/// has no Julian Day facility, so `Date.timeIntervalSince1970` is the exact, time-zone-free bridge. `Calendar` is
/// deliberately avoided, since this code never touches calendar components.
struct JulianDay {
    var value: Double

    static let unixEpoch = JulianDay(value: 2_440_587.5) // 1970-01-01 00:00 UTC
    static let j2000 = JulianDay(value: 2_451_545.0) // 2000-01-01 12:00 TT
    private enum Constants {
        /// Days in a Julian century, the time unit the Meeus polynomial series are expressed in.
        static let daysPerCentury = 36525.0
        static let secondsPerDay = 86400.0
    }

    init(value: Double) {
        self.value = value
    }

    init(_ date: Date) {
        self.value = date.timeIntervalSince1970 / Constants.secondsPerDay + Self.unixEpoch.value
    }

    var daysSinceJ2000: Double {
        value - Self.j2000.value
    }

    var centuriesSinceJ2000: Double {
        daysSinceJ2000 / Constants.daysPerCentury
    }
}

// MARK: - Constants

public enum CelestialConstants {
    /// Earth's equatorial radius, which is also the unit the Moon's distance is reported in.
    static let earthRadiusKm: Double = 6378.14
    /// The mean distance from the Earth to the Moon.
    static let moonMeanDistanceKm = 385_000.56
    /// Mean lunar radius in Earth radii (1737.4 / 6378.14). The Moon is rendered true to scale, and this is the single
    /// source for the value the renderer feeds the eclipse shaders.
    public static let moonRadiusEarthRadii: Float = 0.2724
    /// The Sun's angular radius as seen from Earth. Drives how wide the eclipse penumbra ramps. Mirrored by the shader
    /// constant `sunAngularRadius` in `MapGlobeShaders.metal`, which can't read Swift constants, so a change here must
    /// be made there too.
    public static let sunAngularRadius = Angle.radians(0.00465)

    /// The north galactic pole (J2000: RA 192.85948°, Dec +27.12825°) as a unit direction, mapped through the same
    /// latitude/longitude convention as terrestrial directions with right ascension standing in for longitude. The
    /// celestial sphere's rotation against the Earth (sidereal time) is deliberately not applied: the rendered
    /// starfield is Earth-fixed by design, so only the Milky Way band's orientation *relative to the stars* is physical
    /// — the shared frame is what keeps them consistent.
    public static let galacticNorthPole = GlobeGeometry.unitSphere(
        latitudeDegrees: 27.12825,
        longitudeDegrees: 192.85948
    )

    /// Direction to the galactic centre (Sagittarius A*, J2000: RA 266.41683°, Dec −29.00781°), mapped through the same
    /// convention as the pole. The Milky Way is brightest and broadest here, so the sky glow lifts toward it.
    public static let galacticCentre = GlobeGeometry.unitSphere(
        latitudeDegrees: -29.00781,
        longitudeDegrees: 266.41683
    )
}

/// A mean element as a quadratic `a + b*t + c*t*t` in degrees, with `t` in Julian centuries, evaluated with
/// `callAsFunction` and handed back as an `Angle`. Named coefficients rather than a bare `[Double]`, so the coefficient
/// order can't be misread. Every mean element here is a quadratic.
struct Quadratic {
    let a, b, c: Double

    init(a: Double, b: Double, c: Double) {
        (self.a, self.b, self.c) = (a, b, c)
    }

    func callAsFunction(_ t: Double) -> Angle {
        .degrees(a + b * t + c * t * t)
    }
}

// MARK: - Ephemeris

/// Geocentric Sun and Moon positions as model-space directions on the globe, the sub-solar and sub-lunar points where
/// the body is directly overhead, plus the Moon's centre-to-centre distance in Earth radii. Drives the day/night
/// terminator, the Moon's phase and sky position, and the eclipse geometry.
///
/// An abridged Meeus lunar series, keeping the dominant periodic terms, plus the standard solar series. Good to roughly
/// an arcminute, which is enough that solar and lunar eclipses fall on their real dates: the Moon moves about half a
/// degree per hour, so an arcminute is a couple of minutes of time. UTC is taken as terrestrial time, since the
/// difference of about 70 seconds is well below this precision.
public enum Meeus {
    /// The four fundamental arguments of the lunar theory, evaluated for an instant (Meeus, chapter 47): the mean
    /// elongation of the Moon from the Sun D, the Sun's mean anomaly M, the Moon's mean anomaly M', and the argument of
    /// latitude F. Each periodic term is a sine or cosine of an integer combination of these.
    struct FundamentalArguments {
        let d, m, mp, f: Angle
    }

    public struct Positions: Sendable {
        /// Sub-solar point as a model-space unit vector: where the Sun is directly overhead.
        public let sunDirection: SIMD3<Float>
        /// Sub-lunar point as a model-space unit vector: where the Moon is directly overhead.
        public let moonDirection: SIMD3<Float>
        /// Earth-centre to Moon-centre distance, in Earth radii.
        public let moonDistance: Float
    }

    /// One row of a Meeus periodic-term table (chapter 47, tables 47.A and 47.B): an amplitude (longitude and latitude
    /// in millionths of a degree, distance in metres) and the integer multipliers `d, m, mp, f` of the four fundamental
    /// arguments. The term's argument is the linear combination `d*D + m*M + mp*M' + f*F`. Amplitudes are summed with
    /// `sin` for longitude and latitude, and `cos` for distance.
    struct PeriodicTerm {
        let amplitude: Double
        let d, m, mp, f: Int

        /// `d*D + m*M + mp*M' + f*F`, the angle whose sine or cosine this term contributes.
        func argument(_ a: FundamentalArguments) -> Angle {
            d * a.d + m * a.m + mp * a.mp + f * a.f
        }
    }

    /// Mean elements as quadratics in `t` (Julian centuries since J2000), in degrees. The lunar elements are Meeus
    /// chapter 47, and the solar mean longitude L0 is Meeus 25.2. Coefficient tables only. The fundamental arguments
    /// the periodic summation depends on are formed in `positions`.
    enum MeanElement {
        static let moonLongitude = Quadratic(a: 218.3164477, b: 481_267.88123421, c: -0.0015786) // L'
        static let elongation = Quadratic(a: 297.8501921, b: 445_267.1114034, c: -0.0018819) // D
        static let sunAnomaly = Quadratic(a: 357.5291092, b: 35999.0502909, c: -0.0001536) // M
        static let moonAnomaly = Quadratic(a: 134.9633964, b: 477_198.8675055, c: 0.0087414) // M'
        static let latitudeArg = Quadratic(a: 93.2720950, b: 483_202.0175233, c: -0.0036539) // F
        static let sunLongitude = Quadratic(a: 280.46646, b: 36000.76983, c: 0.0003032) // L0
    }

    public static func positions(at date: Date) -> Positions {
        positions(on: JulianDay(date))
    }

    static func positions(on day: JulianDay) -> Positions {
        let t = day.centuriesSinceJ2000 // Julian centuries from J2000

        let fundamentals = FundamentalArguments(
            d: MeanElement.elongation(t), // mean elongation of the Moon from the Sun
            m: MeanElement.sunAnomaly(t), // Sun mean anomaly
            mp: MeanElement.moonAnomaly(t), // Moon mean anomaly
            f: MeanElement.latitudeArg(t) // argument of latitude
        )

        let moon = moonPosition(on: day, using: fundamentals)
        let sun = sunPosition(on: day, anomaly: fundamentals.m)

        let obliquity = Angle.degrees(23.439291 - 0.0130042 * t) // Meeus 22.2: obliquity of the ecliptic
        // Greenwich mean sidereal time (Meeus 12.4), the geographic longitude of the vernal equinox right now. Its
        // linear term is deliberately in days since J2000, since the rotation is fast, unlike everything else here
        // which is in centuries.
        let gmst = Angle.degrees(280.46061837 + 360.98564736629 * day.daysSinceJ2000 + 0.000387933 * t * t)

        // Ecliptic to equatorial to geographic sub-point, as a typed pipeline that can only be chained in the
        // physically meaningful order.
        let sunSubPoint = sun
            .equatorial(obliquity: obliquity)
            .subPoint(gmst: gmst)
        let moonSubPoint = moon.coordinate
            .equatorial(obliquity: obliquity)
            .subPoint(gmst: gmst)

        return Positions(
            sunDirection: GlobeGeometry.unitSphere(sunSubPoint),
            moonDirection: GlobeGeometry.unitSphere(moonSubPoint),
            moonDistance: Float(moon.distance / CelestialConstants.earthRadiusKm)
        )
    }

    /// The Sun's geocentric ecliptic position (Meeus 25.3 and 25.4). Latitude is effectively zero by definition.
    static func sunPosition(on day: JulianDay, anomaly m: Angle) -> EclipticCoordinate {
        let t = day.centuriesSinceJ2000 // Julian centuries from J2000

        let l0 = MeanElement.sunLongitude(t)
        // Equation of the centre C (Meeus 25.4).
        let c = Angle.degrees(
            (1.914602 - 0.004817 * t) * sin(m)
                + (0.019993 - 0.000101 * t) * sin(2 * m)
                + 0.000289 * sin(3 * m)
        )

        return EclipticCoordinate(longitude: l0 + c, latitude: .degrees(0))
    }

    /// The Moon's geocentric ecliptic position and Earth-centre distance, from the abridged ELP-2000 periodic series
    /// (Meeus, Ch. 47).
    static func moonPosition(on day: JulianDay, using args: FundamentalArguments)
        -> (coordinate: EclipticCoordinate, distance: Double) {
        let t = day.centuriesSinceJ2000 // Julian centuries from J2000
        let lp = MeanElement.moonLongitude(t) // L', Moon mean longitude

        let microDegrees = 1_000_000.0
        let metres = 1000.0
        func series(_ terms: [PeriodicTerm], _ trig: (Angle) -> Double, scaledBy unit: Double) -> Double {
            terms.sum(against: args, trig) / unit
        }

        let longitude = lp + .degrees(series(.longitudeTerms, sin, scaledBy: microDegrees))
        let latitude = Angle.degrees(series(.latitudeTerms, sin, scaledBy: microDegrees))
        let distance = CelestialConstants.moonMeanDistanceKm + series(.distanceTerms, cos, scaledBy: metres)

        return (EclipticCoordinate(longitude: longitude, latitude: latitude), distance)
    }
}

extension [Meeus.PeriodicTerm] {
    /// The sum of amplitude times trig(term argument) over the table: the periodic correction it contributes.
    func sum(against args: Meeus.FundamentalArguments, _ trig: (Angle) -> Double) -> Double {
        reduce(0) { $0 + $1.amplitude * trig($1.argument(args)) }
    }

    fileprivate static let longitudeTerms: Self = [
        Element(amplitude: 6_288_774, d: 0, m: 0, mp: 1, f: 0),
        Element(amplitude: 1_274_027, d: 2, m: 0, mp: -1, f: 0),
        Element(amplitude: 658_314, d: 2, m: 0, mp: 0, f: 0),
        Element(amplitude: 213_618, d: 0, m: 0, mp: 2, f: 0),
        Element(amplitude: -185_116, d: 0, m: 1, mp: 0, f: 0),
        Element(amplitude: -114_332, d: 0, m: 0, mp: 0, f: 2),
        Element(amplitude: 58793, d: 2, m: 0, mp: -2, f: 0),
        Element(amplitude: 57066, d: 2, m: -1, mp: -1, f: 0),
        Element(amplitude: 53322, d: 2, m: 0, mp: 1, f: 0),
        Element(amplitude: 45758, d: 2, m: -1, mp: 0, f: 0),
        Element(amplitude: -40923, d: 0, m: 1, mp: -1, f: 0),
        Element(amplitude: -34720, d: 1, m: 0, mp: 0, f: 0),
        Element(amplitude: -30383, d: 0, m: 1, mp: 1, f: 0),
        Element(amplitude: 15327, d: 2, m: 0, mp: 0, f: -2),
        Element(amplitude: -12528, d: 0, m: 0, mp: 1, f: 2),
        Element(amplitude: 10980, d: 0, m: 0, mp: 1, f: -2),
        Element(amplitude: 10675, d: 4, m: 0, mp: -1, f: 0),
        Element(amplitude: 10034, d: 0, m: 0, mp: 3, f: 0),
    ]

    fileprivate static let latitudeTerms: Self = [
        Element(amplitude: 5_128_122, d: 0, m: 0, mp: 0, f: 1),
        Element(amplitude: 280_602, d: 0, m: 0, mp: 1, f: 1),
        Element(amplitude: 277_693, d: 0, m: 0, mp: 1, f: -1),
        Element(amplitude: 173_237, d: 2, m: 0, mp: 0, f: -1),
        Element(amplitude: 55413, d: 2, m: 0, mp: -1, f: 1),
        Element(amplitude: 46271, d: 2, m: 0, mp: -1, f: -1),
        Element(amplitude: 32573, d: 2, m: 0, mp: 0, f: 1),
        Element(amplitude: 17198, d: 0, m: 0, mp: 2, f: 1),
        Element(amplitude: 9266, d: 2, m: 0, mp: 1, f: -1),
        Element(amplitude: 8822, d: 0, m: 0, mp: 2, f: -1),
        Element(amplitude: 8216, d: 2, m: -1, mp: 0, f: -1),
        Element(amplitude: 4324, d: 2, m: 0, mp: -2, f: -1),
        Element(amplitude: 4200, d: 2, m: 0, mp: 1, f: 1),
    ]

    fileprivate static let distanceTerms: Self = [
        Element(amplitude: -20_905_355, d: 0, m: 0, mp: 1, f: 0),
        Element(amplitude: -3_699_111, d: 2, m: 0, mp: -1, f: 0),
        Element(amplitude: -2_955_968, d: 2, m: 0, mp: 0, f: 0),
        Element(amplitude: -569_925, d: 0, m: 0, mp: 2, f: 0),
        Element(amplitude: 246_158, d: 2, m: 0, mp: -2, f: 0),
        Element(amplitude: -204_586, d: 2, m: -1, mp: 0, f: 0),
        Element(amplitude: -170_733, d: 2, m: 0, mp: 1, f: 0),
        Element(amplitude: -152_138, d: 2, m: -1, mp: -1, f: 0),
        Element(amplitude: -129_620, d: 0, m: 1, mp: -1, f: 0),
        Element(amplitude: 108_743, d: 1, m: 0, mp: 0, f: 0),
        Element(amplitude: 104_755, d: 0, m: 1, mp: 1, f: 0),
    ]
}
