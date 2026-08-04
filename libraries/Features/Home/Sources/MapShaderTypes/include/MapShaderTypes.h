//
//  Created on 30.06.2026 by John Biggs.
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

#ifndef MapShaderTypes_h
#define MapShaderTypes_h

#include <simd/simd.h>

// Single source of truth for the struct layouts shared between the CPU and the GPU. This header is
// included by the Metal shaders and imported into Swift as the `MapShaderTypes` module, so the per-draw
// uniform structs are laid out exactly once instead of being hand-mirrored in two places.
//
// `<simd/simd.h>` is built to be included from both sides: under the Metal compiler it maps
// `vector_floatN` and `matrix_float4x4` to Metal's native `floatN` and `float4x4`, and under Swift they
// import as `SIMD<N><Float>` and `simd_float4x4`. One definition therefore yields identical layouts on
// both sides, which is Apple's sanctioned pattern for sharing types with Metal. The Swift-only ergonomics
// live in `MapUniforms.swift`.

// Globe fill, border, and Moon uniforms (vertex and fragment).
typedef struct {
    matrix_float4x4 mvp;        // perspective, view, and globe rotation multiplied together
    vector_float3 sunDirection; // model-space unit direction toward the sun (the sub-solar point)
    vector_float3 sunTint;      // color of the sunlight (connection green or red); white is neutral
    float borderHalfWidth;      // sphere-space half-width of the path currently being drawn
    float lightFade;            // 0 is flat (decorative), 1 is day/night lighting; the app renders 1, the geometry snapshots 0
    float tintStrength;         // how strongly the sunlight colors this draw; land takes more than the sea
    float moonRadius;           // Moon radius in Earth radii; 0 disables the eclipse shadows
    vector_float3 moonCenter;   // model-space Moon centre (sub-lunar direction scaled by distance, Earth radii)
} MapUniforms;

// One border segment: two unit-sphere endpoints, baked by MapBaker into `world-globe.bin`, uploaded
// verbatim as the border pass's instance buffer, and expanded into a tangent-plane ribbon in the vertex
// shader. Defined here for the same one-layout guarantee as the uniforms. MapModel re-exports it as its
// own `MapGlobeSegment`.
typedef struct {
    vector_float3 a;
    vector_float3 b;
} MapGlobeSegment;

// Instanced city-point billboards.
typedef struct {
    matrix_float4x4 mvp;        // same model-to-clip matrix as the globe, so the dots track it exactly
    vector_float3 cameraTarget; // camera-facing direction
    float horizonCosThreshold;  // the visible-cap cull threshold (1/distance), fed by the CPU
    vector_float2 viewportSize; // drawable size in pixels, for a constant on-screen dot size at any zoom
    float diameter;             // dot fill diameter in pixels
    float fade;                 // overall opacity (the open/close dissolve; 0 once clusters take over)
    vector_float4 fillColor;    // dot fill color (straight, not premultiplied)
} PinUniforms;

// One instanced star billboard.
typedef struct {
    vector_float3 direction; // unit direction on the celestial sphere
    float radius;            // dot radius in points
    float brightness;        // base alpha, 0 to 1
} StarInstance;

// The instanced starfield pass.
typedef struct {
    matrix_float4x4 mvp;
    vector_float2 viewportSize; // drawable size in pixels, for a constant on-screen dot size
    float scale;                // points to pixels (the display scale)
    float fade;                 // overall alpha (the open/close dissolve times the zoom-out ramp)
} StarUniforms;

// The full-screen Milky Way sky-glow pass. Unlike the discrete star billboards, this is a single
// continuous field: a fullscreen triangle whose fragment shader reconstructs each pixel's model-space view
// ray through `inverseMVP` and paints an FBM-textured Gaussian band around the galactic plane. The
// triangle's NDC corners live in the vertex shader alone and the far points derive from them through this
// one matrix, so the two sides cannot drift.
typedef struct {
    matrix_float4x4 inverseMVP;   // clip-to-model, for per-pixel view-ray reconstruction
    vector_float3 cameraPosition; // model-space camera position (facing direction times distance)
    vector_float3 pole;           // model-space galactic north pole
    vector_float3 centre;         // model-space direction to the galactic centre (the brightness peak)
    float fade;                   // overall opacity (the zoom-out ramp times the open/close dissolve)
} SkyGlowUniforms;

// The single sun-glow billboard.
typedef struct {
    matrix_float4x4 mvp;
    vector_float3 sunDirection; // model-space direction toward the sun (the sub-solar point)
    vector_float2 viewportSize; // drawable size in pixels, for a constant on-screen glow size
    float radiusPixels;         // glow radius in pixels
    float fade;                 // overall opacity (the open/close dissolve)
    vector_float3 color;        // glow tint (the connection color); the white core fades into it
} SunUniforms;

#endif /* MapShaderTypes_h */
