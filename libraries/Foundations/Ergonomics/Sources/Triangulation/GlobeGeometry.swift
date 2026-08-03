//
//  Created on 22/06/2026.
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
import simd

// MARK: - Globe geometry

public enum GlobeGeometry {
    /// Maps a geographic coordinate to a point on the unit sphere centered at the origin (the point also *is* its
    /// surface normal). y-up, with `-z` on the longitude term so east appears on the right when a hemisphere faces the
    /// camera, matching a real globe.
    public static func unitSphere(latitudeDegrees latitude: Float, longitudeDegrees longitude: Float) -> SIMD3<Float> {
        let lat = latitude * .pi / 180
        let lon = longitude * .pi / 180
        return SIMD3<Float>(cos(lat) * cos(lon), sin(lat), -cos(lat) * sin(lon))
    }

    /// `GeographicCoordinate` convenience over the Float entry point above.
    public static func unitSphere(_ coordinate: GeographicCoordinate) -> SIMD3<Float> {
        unitSphere(
            latitudeDegrees: Float(coordinate.latitude.degrees),
            longitudeDegrees: Float(coordinate.longitude.degrees)
        )
    }

    /// Inverse of `unitSphere`: recovers the geographic coordinate of a point on (or direction toward) the unit sphere,
    /// for turning an arbitrary direction like a cluster centre back into a latitude and longitude the camera can be
    /// aimed at. Round-trips with `unitSphere`, apart from the longitude wrap at the poles.
    public static func coordinate(of direction: SIMD3<Float>) -> GeographicCoordinate {
        let n = simd_normalize(direction)
        // x = cos(lat) * cos(lon) and -z = cos(lat) * sin(lon), so lon = atan2(-z, x). The y clamp keeps normalisation
        // round-off from pushing the asin out of its domain.
        return GeographicCoordinate(
            latitude: .asin(max(-1, min(1, Double(n.y)))),
            longitude: .atan2(Double(-n.z), Double(n.x))
        )
    }
}

/// Cosine of the angle between two directions: their dot product, clamped to [-1, 1] so `Float` round-off can't push an
/// `acos` out of its domain. Assumes unit-length inputs. This is the hot-loop fast path for code that only compares
/// directions or finds an extreme, with no `acos` to pay.
public func cosAngle(between a: SIMD3<Float>, _ b: SIMD3<Float>) -> Float {
    max(-1, min(1, simd_dot(a, b)))
}

/// Great-circle angle between two unit-sphere directions. The single home for the `acos(clamp(dot))` idiom, so the
/// clamp guarding `acos` against `Float` drift lives here once. In a tight loop that only needs to compare angles or
/// find the largest, prefer `cosAngle(between:_:)` and skip the `acos` entirely.
public func angle(between a: SIMD3<Float>, _ b: SIMD3<Float>) -> Angle {
    .acos(Double(cosAngle(between: a, b)))
}

/// A point on the Earth's surface, the type both ends of `GlobeGeometry` speak.
public struct GeographicCoordinate: Sendable, Equatable {
    public let latitude: Angle
    public let longitude: Angle

    public init(latitude: Angle, longitude: Angle) {
        self.latitude = latitude
        self.longitude = longitude
    }
}
