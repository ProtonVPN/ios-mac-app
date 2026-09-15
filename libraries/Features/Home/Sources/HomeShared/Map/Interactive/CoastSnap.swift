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

/// Snaps a coastal location onto its country's rendered land. The globe is baked from a simplified coastline, so a city
/// at its true coordinate can fall just offshore and read as "in the ocean" (Nuuk being the best example). This nudges
/// such a pin to the nearest point on its own country's land, never another country's.
enum CoastSnap {
    /// Largest correction allowed, 1.5 degrees or about 165 km: comfortably more than any gap the coastline
    /// simplification opens up, and far less than the distance to a wrong country. A pin whose resolved country
    /// geometry doesn't actually contain its region, like a territory keyed under a distant mainland, is left alone.
    /// The inland nudge below can extend the total correction to `maxSnapAngle + inlandNudge`.
    static let maxSnapAngle = Angle.degrees(1.5)

    /// The most the snapped pin is pushed past the coastline, when the pushed point is verifiably on the country's
    /// land. The boundary point itself sits exactly on the coastline, so a pin centered there still hangs half over
    /// the water and reads as offshore at the pin's own size. The actual nudge is the smaller of this and half the
    /// snap distance, held to a floor of a few hundred meters, so a pin needing a slight correction is not pushed
    /// an entire 20 km.
    static let inlandNudge = Angle.degrees(0.2)

    private enum Dimensions {
        /// The smallest inland nudge, in sphere radians: about 300 meters, invisible at any zoom the globe
        /// reaches, yet far enough inside that `lands` accepts a pin that sat exactly on the boundary line.
        static let minimumNudge: Float = 5e-5
    }

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

    /// Snaps `direction` onto `country`'s land: the nearest point on the land's boundary, pushed a little inside
    /// where the land allows. Returns it unchanged if it's already on that land, or if the nearest land is farther
    /// than `maxSnapAngle`. Takes the mesh and country as parameters so tests can inject geometry.
    ///
    /// The target is the nearest point on any triangle edge, not the nearest vertex. The nearest edge point can
    /// sit anywhere along the land's boundary, while a vertex snap could land only on the corners the
    /// triangulation happened to choose: Liechtenstein has four, so every offshore pin there would sit on one of
    /// four spots.
    static func snap(_ direction: SIMD3<Float>, to country: MapGlobeCountry, in mesh: MapGlobeMesh) -> SIMD3<Float> {
        var nearest = direction
        var nearestDot: Float = -2 // cos(angle), larger is nearer. Below any real dot, so the first candidate wins.
        for triangle in mesh.triangles(of: country) {
            if triangle.robustlyContains(direction) {
                return direction
            } // already on this country's land
            for (a, b) in [(triangle.a, triangle.b), (triangle.b, triangle.c), (triangle.c, triangle.a)] {
                let candidate = nearestPoint(on: (a, b), to: direction)
                let dot = simd_dot(direction, candidate)
                if dot > nearestDot {
                    nearestDot = dot
                    nearest = candidate
                }
            }
        }
        // Outside the land: snap onto the nearest boundary point, but only within `maxSnapAngle`. Land farther
        // out means the resolved geometry probably doesn't contain this pin's region, so leave it where it is.
        guard angle(between: direction, nearest) <= maxSnapAngle else { return direction }
        return nudgedInland(from: direction, past: nearest, on: country, in: mesh)
    }

    /// The point of the edge `[a, b]` nearest to `p`, all unit vectors: takes the nearest point on the straight
    /// segment between the endpoints and normalizes it back onto the sphere.
    ///
    /// On the sphere the edge is an arc, and a normalized point of the segment is a point of the arc, so the only
    /// error is in where along the arc the result sits: at most twenty meters for an edge a degree long, and no
    /// boundary edge is longer than that. The mesh's longer edges all cross the country's interior, which is never
    /// nearer to an offshore pin than the boundary, so their larger error cannot change the point `snap` picks.
    private static func nearestPoint(on edge: (SIMD3<Float>, SIMD3<Float>), to p: SIMD3<Float>) -> SIMD3<Float> {
        let span = edge.1 - edge.0
        let lengthSquared = simd_length_squared(span)
        guard lengthSquared > .ulpOfOne else { return edge.0 }
        let fraction = min(max(simd_dot(p - edge.0, span) / lengthSquared, 0), 1)
        return simd_normalize(edge.0 + fraction * span)
    }

    /// Continues past the boundary point along the direction the pin approached it from, which locally points straight
    /// inland, stepping by the bounded nudge. Halves the step once before settling for the boundary point itself, and
    /// accepts only a point that verifiably lands on the country's fill, since a thin sliver or a tiny island can be
    /// overshot.
    private static func nudgedInland(
        from direction: SIMD3<Float>,
        past nearest: SIMD3<Float>,
        on country: MapGlobeCountry,
        in mesh: MapGlobeMesh
    ) -> SIMD3<Float> {
        let step = nearest - direction
        guard simd_length_squared(step) > 1e-12 else { return nearest } // the raw point is the boundary point itself
        let inland = simd_normalize(step) // the chord approximates the tangent at these sub-degree separations
        // The floor of a few hundred meters carries a pin that sat exactly on the boundary far enough inside that
        // `lands` accepts it.
        let nudge = min(Float(inlandNudge.radians), max(simd_length(step) * 0.5, Dimensions.minimumNudge))
        for factor in [1, 0.5] as [Float] {
            let candidate = simd_normalize(nearest + factor * nudge * inland)
            if lands(candidate, on: country, in: mesh) {
                return candidate
            }
        }
        return nearest
    }

    /// Whether `point` lies on any of the country's fill triangles.
    private static func lands(_ point: SIMD3<Float>, on country: MapGlobeCountry, in mesh: MapGlobeMesh) -> Bool {
        mesh.triangles(of: country).contains { $0.robustlyContains(point) }
    }
}

private extension SphericalTriangle {
    /// `contains`, with a proximity precondition: the point must lie within twice the triangle's widest side of
    /// vertex `a`, which every point the triangle contains does. Without the precondition, the sign test amounts
    /// to floating-point noise for a point far from a tiny sliver of a triangle, and the noise can read as inside.
    func robustlyContains(_ point: SIMD3<Float>) -> Bool {
        // The test runs in cosines: the threshold for twice the widest side comes from cos(2x) = 2cos(x)^2 - 1,
        // and a larger dot product means a nearer point. When the widest side passes ninety degrees (a negative
        // `widest`), twice it covers the whole sphere and every point should qualify, but the identity's value
        // rises again and would exclude points near the antipode of `a`. The threshold is fixed at -1 instead.
        let widest = min(min(simd_dot(a, b), simd_dot(b, c)), simd_dot(c, a))
        let reach = widest < 0 ? -1 : 2 * widest * widest - 1
        return simd_dot(point, a) >= reach && contains(point)
    }
}
