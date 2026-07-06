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

/// A latitude/longitude sphere tessellation on the unit sphere: the base ocean globe under the baked land.
/// Placing each vertex through `GlobeGeometry.unitSphere` keeps it on exactly the same coordinate
/// convention as the land, notably the negated z on the longitude term, so the two can't drift to
/// different handedness. A one-time cold build, so it stays on the readable typed path.
public enum UVSphere {
    /// Outward-wound (counter-clockwise seen from outside) unit-sphere mesh of `stacks` latitude bands by
    /// `slices` longitude segments. Outward winding matches the land, so one back-face cull pass hides the
    /// far hemisphere of both.
    public static func mesh(stacks: Int, slices: Int) -> (vertices: [SIMD3<Float>], indices: [UInt32]) {
        var vertices: [SIMD3<Float>] = []
        for stack in 0 ... stacks {
            let latitude = 90 - Float(stack) / Float(stacks) * 180 // +90 down to -90 degrees
            for slice in 0 ... slices {
                let longitude = Float(slice) / Float(slices) * 360 - 180 // -180 to +180 degrees
                vertices.append(GlobeGeometry.unitSphere(latitudeDegrees: latitude, longitudeDegrees: longitude))
            }
        }
        let stride = slices + 1
        var indices: [UInt32] = []
        for stack in 0 ..< stacks {
            for slice in 0 ..< slices {
                let i0 = UInt32(stack * stride + slice)
                let i1 = UInt32(stack * stride + slice + 1)
                let i2 = UInt32((stack + 1) * stride + slice)
                let i3 = UInt32((stack + 1) * stride + slice + 1)
                appendOutward(&indices, i0, i2, i1, from: vertices)
                appendOutward(&indices, i1, i2, i3, from: vertices)
            }
        }
        return (vertices, indices)
    }

    /// Appends a triangle, swapping the last two indices if it faces inward, so winding is consistently
    /// outward. The pole rows collapse one edge of each quad to a point, and those sliver triangles are
    /// skipped rather than emitted with (near) zero area.
    private static func appendOutward(
        _ indices: inout [UInt32],
        _ a: UInt32,
        _ b: UInt32,
        _ c: UInt32,
        from verts: [SIMD3<Float>]
    ) {
        let v0 = verts[Int(a)], v1 = verts[Int(b)], v2 = verts[Int(c)]
        guard simd_length_squared(simd_cross(v1 - v0, v2 - v0)) > Constants.minTriangleCrossSquared else { return }
        if isOutwardFacing(v0, v1, v2) {
            indices.append(contentsOf: [a, b, c])
        } else {
            indices.append(contentsOf: [a, c, b])
        }
    }

    private enum Constants {
        /// Squared cross-product length below which a triangle is a degenerate sliver. Pole slivers come
        /// out around 1e-17 and the smallest real quad triangle around 1e-5, so this separates them with
        /// orders of magnitude to spare on either side.
        static let minTriangleCrossSquared: Float = 1e-12
    }
}
