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

// Helpers for the globe's orbit-camera quaternion maths, kept as plain `simd_quatf` extensions rather than a wrapper
// type so they compose with simd's own quaternion algebra and never need unwrapping where the camera matrix is built.
// Policy like the north-up clamp stays with the interactive view. These are just the reusable rotations.
public extension simd_quatf {
    /// The rotation that brings model-space `target` onto the camera's +z axis (facing the camera), keeping north
    /// (`worldUp`, +y) roughly up. Builds an orthonormal view basis from `target` and `worldUp`, swapping to a fallback
    /// up axis within `poleGuardDot` of the pole, where `target` and `worldUp` are near-parallel and the cross product
    /// would collapse. Of a rotation's two quaternion encodings, q and -q, this picks from the basis alone, with no
    /// memory of any previous orientation; run the result through `aligned(to:)` before interpolating toward it, or the
    /// animation can rotate the long way round.
    static func lookingAt(
        _ target: SIMD3<Float>,
        worldUp: SIMD3<Float> = SIMD3<Float>(0, 1, 0),
        poleGuardDot: Float = 0.999
    ) -> simd_quatf {
        let forward = simd_normalize(target)
        var up = worldUp
        if abs(simd_dot(forward, up)) > poleGuardDot {
            up = SIMD3<Float>(0, 0, 1)
        }
        let right = simd_normalize(simd_cross(up, forward))
        let trueUp = simd_cross(forward, right)
        // Rows (right, up, forward) map model directions into the view frame.
        return simd_quatf(simd_float3x3(rows: [right, trueUp, forward]))
    }

    /// Returns this quaternion negated when it lies in the opposite hemisphere from `reference` (q and -q are the same
    /// orientation), so interpolating from `reference` to it rotates the short way round rather than the long way. A
    /// no-op when they're already aligned.
    func aligned(to reference: simd_quatf) -> simd_quatf {
        simd_dot(vector, reference.vector) < 0 ? simd_quatf(vector: -vector) : self
    }
}
