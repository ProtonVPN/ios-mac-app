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
    float3 sunDirection;   // model-space unit direction toward the sun (subsolar point)
    float3 sunTint;        // colour of the sunlight (the connection green/red); white = neutral
    float borderHalfWidth; // sphere-space half-width of the path currently being drawn
    float lightFade;       // 0 = flat (decorative), 1 = full day/night terminator lighting
    float tintStrength;    // how strongly the sunlight colours this draw — land takes more than the sea
};

struct GlobeSegment {
    float3 a; // unit-sphere endpoints
    float3 b;
};

// Surface normal (= model-space unit-sphere position) carried to the fragment so it can shade the globe
// by the sun direction (day/night terminator).
struct GlobeVaryings {
    float4 position [[position]];
    float3 normal;
};

// Fills (and the base ocean sphere): positions are unit-sphere points, which are also the surface normals.
vertex GlobeVaryings vertex_globe_fill(const device float3 *positions [[buffer(0)]],
                                       constant GlobeUniforms &u [[buffer(1)]],
                                       uint vid [[vertex_id]]) {
    GlobeVaryings out;
    out.position = u.mvp * float4(positions[vid], 1.0);
    out.normal = positions[vid];
    return out;
}

// Borders: instanced ribbon expansion on the sphere. Each segment becomes a quad in the local tangent
// plane — the offset is perpendicular to the segment direction *and* to the surface normal (the
// endpoint itself), via cross products — extended by a square cap so corners don't gap.
vertex GlobeVaryings vertex_globe_border(const device GlobeSegment *segs [[buffer(0)]],
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

    GlobeVaryings out;
    out.position = u.mvp * float4(p, 1.0);
    out.normal = endpoint; // surface normal for lighting (the border hugs the surface)
    return out;
}

// Premultiplied output so it composites correctly over the transparent drawable with
// (one, oneMinusSourceAlpha) blending; MSAA coverage antialiases edges at resolve time. Shared by the
// fill and border pipelines. Shades the globe by the sun: the lit hemisphere stays full brightness, the
// night side dims, with a soft terminator — faded in by `lightFade` (flat when 0, e.g. the decorative map).
fragment float4 fragment_solid(GlobeVaryings in [[stage_in]],
                               constant float4 &color [[buffer(0)]],
                               constant GlobeUniforms &u [[buffer(1)]]) {
    // Diffuse sunlight: the lit hemisphere brightens, peaking at the subsolar point and falling off as the
    // cosine of the angle to it, reaching the (slightly dimmed) night level at the terminator — the real
    // day/night line for the sun's current position. We *add* light to the day side rather than multiplying
    // the already-dark base toward black, so the night side stays as visible as the flat map. The added
    // light is tinted with the connection colour, so the sunlight falling on the globe reads green/red.
    float lambert = max(0.0, dot(normalize(in.normal), u.sunDirection));
    float lit = lambert * u.lightFade;              // day-side intensity, faded in with the map open
    float shade = mix(0.85, 1.4, lambert);          // 0.85 = night, 1.4 = full sun at the subsolar point
    float factor = mix(1.0, shade, u.lightFade);
    // The sunlight's colour washes the lit side; the land takes it more strongly than the sea (the
    // continents carry the connection colour, the ocean stays near neutral), so `tintStrength` is per draw.
    float3 rgb = color.rgb * factor + u.sunTint * (u.tintStrength * lit);
    return float4(rgb * color.a, color.a);
}
