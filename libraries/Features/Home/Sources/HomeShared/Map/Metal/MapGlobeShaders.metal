//
//  Created on 20/06/2026.
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

// Globe shaders. The map is on a unit sphere; a single MVP (perspective × view × globe-rotation)
// projects it. Hemisphere occlusion is handled by back-face culling (back-hemisphere triangles face
// away); the far side is simply never drawn.

#include <metal_stdlib>
using namespace metal;

struct GlobeUniforms {
    float4x4 mvp;          // perspective × view × globe rotation
    float borderHalfWidth; // sphere-space half-width of the path currently being drawn
};

struct GlobeSegment {
    float3 a; // unit-sphere endpoints
    float3 b;
};

// Fills (and the base ocean sphere): positions are unit-sphere points. The position also is the
// surface normal — kept implicitly for a future shading/terminator pass.
vertex float4 vertex_globe_fill(const device float3 *positions [[buffer(0)]],
                                constant GlobeUniforms &u [[buffer(1)]],
                                uint vid [[vertex_id]]) {
    return u.mvp * float4(positions[vid], 1.0);
}

// Borders: instanced ribbon expansion on the sphere. Each segment becomes a quad in the local tangent
// plane — the offset is perpendicular to the segment direction *and* to the surface normal (the
// endpoint itself), via cross products — extended by a square cap so corners don't gap.
vertex float4 vertex_globe_border(const device GlobeSegment *segs [[buffer(0)]],
                                  constant GlobeUniforms &u [[buffer(1)]],
                                  uint vid [[vertex_id]],
                                  uint iid [[instance_id]]) {
    GlobeSegment s = segs[iid];
    float3 delta = s.b - s.a;
    float len = length(delta);
    float3 dir = len > 1e-9 ? delta / len : float3(1.0, 0.0, 0.0);
    float halfWidth = u.borderHalfWidth;
    float cap = min(halfWidth, len * 0.5);

    float3 endpoint = (vid < 2) ? s.a : s.b;     // also the surface normal at that endpoint
    float3 base = endpoint + ((vid < 2) ? -dir : dir) * cap;
    float3 tangent = normalize(cross(endpoint, dir)); // perpendicular to dir, in the tangent plane
    float side = (vid & 1) == 0 ? 1.0 : -1.0;
    float3 p = base + tangent * (halfWidth * side);
    return u.mvp * float4(p, 1.0);
}

// Premultiplied output so it composites correctly over the transparent drawable with
// (one, oneMinusSourceAlpha) blending; MSAA coverage antialiases edges at resolve time. Shared by the
// fill and border pipelines.
fragment float4 fragment_solid(constant float4 &color [[buffer(0)]]) {
    return float4(color.rgb * color.a, color.a);
}
