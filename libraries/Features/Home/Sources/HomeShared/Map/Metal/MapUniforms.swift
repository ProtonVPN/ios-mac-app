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

import MapShaderTypes
import simd

// The GPU uniform and instance struct layouts are defined once in `MapShaderTypes.h`, which the shaders also include,
// so the CPU and GPU sides can't drift. This file adds Swift-side ergonomics to those data structures.

extension MapUniforms {
    /// Convenience initializer: the MVP and per-path border width are required, and the lighting and eclipse fields
    /// default to a neutral, unlit configuration. The renderer overwrites most of them per draw, and the snapshot paths
    /// leave them at these defaults. The argument order differs from the C struct's synthesized memberwise initializer
    /// on purpose. That is what lets this defaulted overload coexist with it.
    init(
        mvp: simd_float4x4,
        borderHalfWidth: Float,
        sunDirection: SIMD3<Float> = SIMD3<Float>(0, 0, 1),
        sunTint: SIMD3<Float> = SIMD3<Float>(1, 1, 1),
        lightFade: Float = 0,
        // Neutral, no tint. The renderer owns the real per-draw values and overwrites this before anything reads it. A
        // non-zero default here would just invite tuning a knob that affects no pixel.
        tintStrength: Float = 0,
        moonRadius: Float = 0,
        moonCenter: SIMD3<Float> = SIMD3<Float>(0, 0, 0)
    ) {
        self.init(
            mvp: mvp,
            sunDirection: sunDirection,
            sunTint: sunTint,
            borderHalfWidth: borderHalfWidth,
            lightFade: lightFade,
            tintStrength: tintStrength,
            moonRadius: moonRadius,
            moonCenter: moonCenter
        )
    }
}

// `Equatable` so the renderer rebuilds the (static) starfield instance buffer only when it actually changes.
extension StarInstance: Equatable {
    public static func == (lhs: StarInstance, rhs: StarInstance) -> Bool {
        lhs.direction == rhs.direction && lhs.radius == rhs.radius && lhs.brightness == rhs.brightness
    }
}

// `Equatable` so `GlobeSurfaceView.apply(to:)` can skip the redraw when a body re-evaluation changed nothing.
extension MapUniforms: Equatable {
    public static func == (lhs: MapUniforms, rhs: MapUniforms) -> Bool {
        lhs.mvp == rhs.mvp
            && lhs.sunDirection == rhs.sunDirection
            && lhs.sunTint == rhs.sunTint
            && lhs.borderHalfWidth == rhs.borderHalfWidth
            && lhs.lightFade == rhs.lightFade
            && lhs.tintStrength == rhs.tintStrength
            && lhs.moonRadius == rhs.moonRadius
            && lhs.moonCenter == rhs.moonCenter
    }
}
