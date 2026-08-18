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

/// Ecliptic spherical coordinate: longitude λ measured along the ecliptic, latitude β above/below it.
public struct EclipticCoordinate: Sendable, Equatable {
    public let longitude: Angle // λ
    public let latitude: Angle // β

    public init(longitude: Angle, latitude: Angle) {
        self.longitude = longitude
        self.latitude = latitude
    }
}

/// Equatorial spherical coordinate: right ascension α along the celestial equator, declination δ above it.
public struct EquatorialCoordinate: Sendable, Equatable {
    public let rightAscension: Angle // α
    public let declination: Angle // δ

    public init(rightAscension: Angle, declination: Angle) {
        self.rightAscension = rightAscension
        self.declination = declination
    }
}

extension EclipticCoordinate {
    /// Meeus 13.3 and 13.4: rotate ecliptic (λ, β) by the obliquity of the ecliptic into equatorial (α, δ).
    func equatorial(obliquity ε: Angle) -> EquatorialCoordinate {
        let λ = longitude, β = latitude
        return EquatorialCoordinate(
            rightAscension: .atan2(sin(λ) * cos(ε) - tan(β) * sin(ε), cos(λ)),
            declination: .asin(sin(β) * cos(ε) + cos(β) * sin(ε) * sin(λ))
        )
    }
}

public extension EquatorialCoordinate {
    /// The sub-point: the geographic coordinate with this body directly overhead. The body is overhead where the local
    /// hour angle is zero, that is, where east longitude equals right ascension minus GMST.
    func subPoint(gmst: Angle) -> GeographicCoordinate {
        GeographicCoordinate(latitude: declination, longitude: (rightAscension - gmst).normalizedSigned)
    }
}
