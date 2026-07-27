//
//  Created on 24/06/2026.
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
import Triangulation

/// Snaps a coastal location onto its country's rendered land. The globe is baked from a simplified coastline, so a
/// city at its true coordinate can fall just offshore and read as "in the ocean" (Nuuk being the best example). This
/// nudges such a pin to the nearest point on its own country's land, never another country's.
enum CoastSnap {
    /// Largest correction allowed, 1.5 degrees or about 165 km: comfortably more than any gap the coastline
    /// simplification opens up, and far less than the distance to a wrong country. A pin whose resolved country
    /// geometry doesn't actually contain its region, like a territory keyed under a distant mainland, is simply
    /// left put. The inland nudge below can extend the total correction to `maxSnapAngle + inlandNudge`.
    static let maxSnapAngle = Angle.degrees(1.5)

    /// How far past the nearest coast vertex the snapped pin is pushed inland, when the pushed point is verifiably on
    /// the country's land. The vertex itself sits exactly on the coastline, so a pin centered there still hangs half
    /// over the water and reads as offshore at the pin's own size. Carrying it a little inside makes the correction
    /// visible. About 20 km: small next to any country, big next to a pin.
    static let inlandNudge = Angle.degrees(0.2)

    /// The unit-sphere position to render a location at: its true coordinate, snapped onto the resolved country's coast
    /// if it falls just offshore.
    static func snappedDirection(
        latitudeDegrees latitude: Double,
        longitudeDegrees longitude: Double,
        countryCode code: String
    ) -> SIMD3<Float> {
        let direction = GlobeGeometry.unitSphere(latitudeDegrees: Float(latitude), longitudeDegrees: Float(longitude))
        guard let country = GlobeResource.country(code: code) else { return direction }
        return GlobeResource.withMesh { mesh in
            snap(direction, to: country, in: mesh)
        }
    }

    /// Snaps `direction` onto `country`'s land: the nearest coast vertex, pushed `Self.inlandNudge` inside where the
    /// land allows. Returns it unchanged if it's already on that land, or if the nearest land vertex is farther than
    /// `maxSnapAngle`. Takes the mesh and country as parameters so tests can inject geometry.
    static func snap(_ direction: SIMD3<Float>, to country: MapGlobeCountry, in mesh: MapGlobeMesh) -> SIMD3<Float> {
        var nearest = direction
        var nearestDot: Float = -2 // cos(angle), larger is nearer. Below any real dot, so the first vertex wins.
        for triangle in mesh.triangles(of: country) {
            if triangle.contains(direction) { return direction } // already on this country's land
            let da = simd_dot(direction, triangle.a); if da > nearestDot { nearestDot = da; nearest = triangle.a }
            let db = simd_dot(direction, triangle.b); if db > nearestDot { nearestDot = db; nearest = triangle.b }
            let dc = simd_dot(direction, triangle.c); if dc > nearestDot { nearestDot = dc; nearest = triangle.c }
        }
        // Outside the land: snap onto the nearest land vertex, but only within the cap. A vertex farther
        // out means the resolved geometry probably doesn't contain this pin's region, so leave it put.
        guard angle(between: direction, nearest) <= maxSnapAngle else { return direction }
        return nudgedInland(from: direction, past: nearest, on: country, in: mesh)
    }

    /// Continues past the vertex along the direction the pin approached it from, which locally points straight inland
    /// by `Self.inlandNudge`. Halves the step once before settling for the vertex itself, and accepts only a point
    /// that verifiably lands on the country's fill, since a thin sliver or a tiny island can be overshot.
    private static func nudgedInland(
        from direction: SIMD3<Float>,
        past nearest: SIMD3<Float>,
        on country: MapGlobeCountry,
        in mesh: MapGlobeMesh
    ) -> SIMD3<Float> {
        let step = nearest - direction
        guard simd_length_squared(step) > 1e-12 else { return nearest } // the raw point is the vertex itself
        let inland = simd_normalize(step) // the chord approximates the tangent at these sub-degree separations
        for factor in [1, 0.5] as [Float] {
            let candidate = simd_normalize(nearest + factor * Float(inlandNudge.radians) * inland)
            if lands(candidate, on: country, in: mesh) { return candidate }
        }
        return nearest
    }

    /// Whether `point` lies on any of the country's fill triangles.
    private static func lands(_ point: SIMD3<Float>, on country: MapGlobeCountry, in mesh: MapGlobeMesh) -> Bool {
        mesh.triangles(of: country).contains { $0.contains(point) }
    }
}
