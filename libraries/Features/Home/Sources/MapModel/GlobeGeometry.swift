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

/// The single source of truth for how a geographic coordinate maps onto the unit globe.
///
/// Two call sites must agree on this exactly or the connection pin drifts off the baked land: the offline
/// baker un-projects map space to lat/long and calls this to place every vertex (`MapBaker`'s
/// `Unprojector`), and the app calls it directly to place the pin at the connected server's coordinates
/// (`HomeMapView`). Keeping it here — in the leaf model module shared by both — makes that agreement
/// structural rather than a comment to remember.
public enum GlobeGeometry {
    /// Maps a geographic coordinate to a point on the unit sphere centred at the origin (the point also
    /// *is* its surface normal). y-up, with `-z` on the longitude term so east appears on the right when a
    /// hemisphere faces the camera, matching a real globe.
    public static func unitSphere(latitudeDegrees latitude: Float, longitudeDegrees longitude: Float) -> SIMD3<Float> {
        let lat = latitude * .pi / 180
        let lon = longitude * .pi / 180
        return SIMD3<Float>(cos(lat) * cos(lon), sin(lat), -cos(lat) * sin(lon))
    }

    /// Inverse of `unitSphere`: recovers the geographic coordinate of a point on (or direction toward) the
    /// unit sphere. Used to re-centre an interactive look-at camera on an arbitrary direction — e.g. the
    /// averaged centre of a cluster of pins — by turning it back into the latitude/longitude the turntable
    /// is parameterised on. Round-trips with `unitSphere` (modulo longitude wrap at the poles).
    public static func coordinate(of direction: SIMD3<Float>) -> (latitudeDegrees: Float, longitudeDegrees: Float) {
        let n = simd_normalize(direction)
        let latitude = asin(max(-1, min(1, n.y))) * 180 / .pi
        // x = cos(lat)·cos(lon), -z = cos(lat)·sin(lon) ⇒ lon = atan2(-z, x).
        let longitude = atan2(-n.z, n.x) * 180 / .pi
        return (latitude, longitude)
    }
}
