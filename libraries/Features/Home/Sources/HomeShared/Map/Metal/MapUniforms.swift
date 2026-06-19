//
//  Created on 19/06/2026.
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

import simd

/// CPU-side mirror of `GlobeUniforms` in `MapGlobeShaders.metal`.
///
/// Layout must match the shader exactly: `simd_float4x4` is 64 bytes / 16-aligned, then a `Float`,
/// giving a 16-aligned stride on both sides. Passed via `setVertexBytes`.
struct MapUniforms {
    var mvp: simd_float4x4
    /// Sphere-space half-width of the path currently being drawn (set per border draw).
    var borderHalfWidth: Float
}
