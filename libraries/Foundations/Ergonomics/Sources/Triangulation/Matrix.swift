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

// The two affine placements the globe renderer and camera build by hand, with the column-major, w = 1
// convention named once instead of re-spelled as raw column literals at each call site. Plain
// `simd_float4x4` out, so they drop straight into an MVP multiply with no wrapper.
public extension simd_float4x4 {
    /// Pure translation along z. The camera's view transform: pushing the globe out in front of a camera
    /// sitting at the origin looking down -z.
    static func translation(z: Float) -> simd_float4x4 {
        simd_float4x4(columns: (
            SIMD4<Float>(1, 0, 0, 0),
            SIMD4<Float>(0, 1, 0, 0),
            SIMD4<Float>(0, 0, 1, 0),
            SIMD4<Float>(0, 0, z, 1)
        ))
    }

    /// Uniform scale by `radius` then translation to `center`: places a unit-radius mesh as a sphere of
    /// the given radius centred at `center`. The Moon's model matrix.
    static func placing(at center: SIMD3<Float>, radius: Float) -> simd_float4x4 {
        simd_float4x4(columns: (
            SIMD4<Float>(radius, 0, 0, 0),
            SIMD4<Float>(0, radius, 0, 0),
            SIMD4<Float>(0, 0, radius, 0),
            SIMD4<Float>(center.x, center.y, center.z, 1)
        ))
    }
}
