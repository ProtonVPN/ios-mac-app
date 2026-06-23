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
/// Layout must match the shader exactly: `simd_float4x4` (64 B, 16-aligned), then `SIMD3<Float>` (16 B,
/// 16-aligned), then two `Float`s — a 16-aligned stride of 96 on both sides. Passed via `setVertexBytes`
/// and (for lighting) `setFragmentBytes`.
struct MapUniforms {
    var mvp: simd_float4x4
    /// Model-space unit direction toward the sun (subsolar point), for day/night shading. Default faces the
    /// camera so the non-lit paths (snapshots, `lightFade == 0`) are unaffected.
    var sunDirection: SIMD3<Float> = .init(0, 0, 1)
    /// Colour of the sunlight (the connection green/red); white = neutral. Default white.
    var sunTint: SIMD3<Float> = .init(1, 1, 1)
    /// Sphere-space half-width of the path currently being drawn (set per border draw).
    var borderHalfWidth: Float
    /// 0 = flat (decorative map / snapshots), 1 = full day/night terminator lighting; faded in for full view.
    var lightFade: Float = 0
    /// How strongly the sunlight colour washes this draw (set per draw — sea more than land).
    var tintStrength: Float = 0.12
}
