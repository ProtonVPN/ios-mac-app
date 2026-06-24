//
//  Created on 30.06.2026 by John Biggs.
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

import simd

/// A triangle whose vertices are unit-sphere directions, with the membership test the coast snap needs. A
/// value type over three directions, so a hot per-country scan can keep walking a flat index buffer and
/// only wrap the three vertices it's currently testing, with no allocation on the inner loop.
public struct SphericalTriangle: Sendable {
    public let a, b, c: SIMD3<Float>

    public init(_ a: SIMD3<Float>, _ b: SIMD3<Float>, _ c: SIMD3<Float>) {
        (self.a, self.b, self.c) = (a, b, c)
    }

    /// Whether `p` lies inside the triangle: on the interior side, the same side as the opposite vertex,
    /// of each great-circle edge. Winding-independent, and correct for a point in the triangle's own
    /// hemisphere, which is the only case the globe tests since a pin is always near its country.
    ///
    /// A degenerate triangle (duplicate or near-collinear vertices, which the baker's vertex weld can emit)
    /// contains nothing. Without the guard, a duplicate vertex zeroes an edge normal and the sign test
    /// becomes `0 >= 0`, true for every point on the sphere, so one bad sliver anywhere in a country's mesh
    /// would make the whole ocean read as part of its land.
    public func contains(_ p: SIMD3<Float>) -> Bool {
        func interior(_ e0: SIMD3<Float>, _ e1: SIMD3<Float>, _ opposite: SIMD3<Float>) -> Bool {
            let normal = simd_cross(e0, e1)
            let side = simd_dot(opposite, normal)
            // `side` over the normal's length is the sine of the opposite vertex's angular height above
            // the edge's great circle. A triangle flatter than 1e-5 radians, about 60 metres on Earth,
            // can't attest an interior side.
            guard abs(side) > Constants.minAttestingSide * simd_length(normal) else { return false }
            return simd_dot(p, normal) * side >= 0
        }
        return interior(a, b, c) && interior(b, c, a) && interior(c, a, b)
    }

    private enum Constants {
        static let minAttestingSide: Float = 1e-5
    }
}

/// Whether the triangle `(v0, v1, v2)` faces outward from the sphere's centre, meaning its geometric
/// normal points the same way as the surface. The baker and the base-sphere builder both wind triangles
/// outward so a single back-face cull hides the far hemisphere of land and ocean alike.
public func isOutwardFacing(_ v0: SIMD3<Float>, _ v1: SIMD3<Float>, _ v2: SIMD3<Float>) -> Bool {
    simd_dot(simd_cross(v1 - v0, v2 - v0), v0) >= 0
}
