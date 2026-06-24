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
    float moonRadius;      // Moon radius in Earth radii (≈0.2725); 0 disables eclipse shadows
    float3 moonCenter;     // model-space Moon-centre position (sub-lunar dir × distance, Earth radii)
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

// Border vertices additionally carry their position within the segment ribbon, so the fragment can round
// the cap into a capsule (see `fragment_globe_border`). `local` = (signed distance along the segment from
// `a`, signed distance across it); `segLength` = the segment length, to clamp the along-distance to the core.
struct BorderVaryings {
    float4 position [[position]];
    float3 normal;
    float2 local;
    float segLength;
};

// Shared globe shading (fill + border): diffuse sunlight added to the day side, tinted with the connection
// colour, faded in by `lightFade`; premultiplied for (one, 1-srcAlpha) blending over the transparent drawable.
static float4 shadeGlobe(float3 normal, float4 color, constant GlobeUniforms &u) {
    float lambert = max(0.0, dot(normalize(normal), u.sunDirection));
    float lit = lambert * u.lightFade;              // day-side intensity, faded in with the map open
    float shade = mix(0.85, 1.4, lambert);          // 0.85 = night, 1.4 = full sun at the subsolar point
    float factor = mix(1.0, shade, u.lightFade);
    float3 rgb = color.rgb * factor + u.sunTint * (u.tintStrength * lit);
    return float4(rgb * color.a, color.a);
}

// Fraction of the Sun's disc covered by a sphere occluder (centre `occCenter`, radius `occRadius`, Earth
// radii) as seen from `point`, with the Sun in (effectively parallel) direction `sunDir`: 0 = Sun clear,
// 1 = fully covered. This is the whole eclipse engine — the Earth dims where the Moon covers the Sun
// (solar), the Moon darkens where the Earth covers it (lunar). Evaluated per fragment, so the Moon's
// parallax (different ground points see it shifted) lands the shadow on the right part of the globe.
static float sunOcclusion(float3 point, float3 sunDir, float3 occCenter, float occRadius) {
    if (occRadius <= 0.0) return 0.0;
    float3 toOcc = occCenter - point;
    float dist = length(toOcc);
    if (dist < 1e-4) return 0.0;
    float3 occDir = toOcc / dist;
    if (dot(occDir, sunDir) <= 0.0) return 0.0; // the occluder must lie toward the Sun
    const float rSun = 0.00465;                 // Sun's angular radius from ~1 AU (rad)
    float rOcc = occRadius / dist;              // the occluder's angular radius from here
    float sep = acos(clamp(dot(occDir, sunDir), -1.0, 1.0));
    // Ramp across the penumbra: first contact at sep = rSun+rOcc, total at sep = |rSun−rOcc|. Capped by the
    // occluder's disc-area ratio so an annular eclipse (Moon smaller than the Sun) never fully covers it.
    float coverage = clamp((rSun + rOcc - sep) / (2.0 * rSun), 0.0, 1.0);
    return min(coverage, min(1.0, (rOcc * rOcc) / (rSun * rSun)));
}

// Day-side darkening of the Earth from a solar eclipse — the Moon passing in front of the Sun above this
// ground point. 1 = no eclipse. Faded out across the terminator (there's no Sun to cover at night): a SMOOTH
// ramp, not a hard `step`, or a penumbra straddling the day/night line shows a sharp edge where the dimming
// cuts off — matching the soft day/night terminator the lighting already uses.
static float eclipseDim(float3 normal, constant GlobeUniforms &u) {
    float3 n = normalize(normal);
    float day = smoothstep(0.0, 0.15, dot(n, u.sunDirection));
    return 1.0 - 0.9 * day * sunOcclusion(n, u.sunDirection, u.moonCenter, u.moonRadius);
}

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
// plane — the offset is perpendicular to the segment direction *and* to the surface normal (the endpoint
// itself), via cross products — extended by a full `halfWidth` cap at each end. The fragment rounds that cap
// into a capsule, so a short segment becomes a dot and adjacent segments' round caps form a smooth round JOIN
// (a square cap's outer corners poked out past the joint — the 1px burrs).
vertex BorderVaryings vertex_globe_border(const device GlobeSegment *segs [[buffer(0)]],
                                          constant GlobeUniforms &u [[buffer(1)]],
                                          uint vid [[vertex_id]],
                                          uint iid [[instance_id]]) {
    GlobeSegment s = segs[iid];
    float3 delta = s.b - s.a;
    float len = length(delta);
    float3 dir = len > 1e-9 ? delta / len : float3(1.0, 0.0, 0.0);
    float halfWidth = u.borderHalfWidth;
    float outer = halfWidth * 1.5; // quad a touch wider than the stroke, so the SDF edge AA has room both sides

    float3 endpoint = (vid < 2) ? s.a : s.b;     // also the surface normal at that endpoint
    float3 base = endpoint + ((vid < 2) ? -dir : dir) * outer;
    float3 tangent = normalize(cross(endpoint, dir)); // perpendicular to dir, in the tangent plane
    float side = (vid & 1) == 0 ? 1.0 : -1.0;
    float3 p = base + tangent * (outer * side);

    BorderVaryings out;
    out.position = u.mvp * float4(p, 1.0);
    out.normal = endpoint; // surface normal for lighting (the border hugs the surface)
    out.local = float2((vid < 2) ? -outer : len + outer, outer * side);
    out.segLength = len;
    return out;
}

// Fill fragment (and the base ocean sphere): the shared sun shading, then dimmed by any solar eclipse.
// Premultiplied for (one, 1-srcAlpha) blending; the dim scales rgb only so the silhouette stays opaque.
fragment float4 fragment_solid(GlobeVaryings in [[stage_in]],
                               constant float4 &color [[buffer(0)]],
                               constant GlobeUniforms &u [[buffer(1)]]) {
    float4 c = shadeGlobe(in.normal, color, u);
    return float4(c.rgb * eclipseDim(in.normal, u), c.a);
}

// Border fragment: rounds the square cap into a capsule. `dist` is the distance from the segment's core (the
// a–b line, clamped) to this pixel; coverage falls from 1 to 0 across the `halfWidth` edge over ~1px
// (`fwidth`), so the rounded cap/join is smoothly antialiased rather than discarded hard (which would alias).
// Premultiplied by coverage so the soft edge composites correctly.
fragment float4 fragment_globe_border(BorderVaryings in [[stage_in]],
                                      constant float4 &color [[buffer(0)]],
                                      constant GlobeUniforms &u [[buffer(1)]]) {
    float along = clamp(in.local.x, 0.0, in.segLength);     // nearest point on the core a–b
    float dist = length(float2(in.local.x - along, in.local.y));
    float aa = max(fwidth(dist), 1e-6);
    float coverage = clamp((u.borderHalfWidth - dist) / aa + 0.5, 0.0, 1.0); // edge centred on halfWidth, ~1px AA
    if (coverage <= 0.0) discard_fragment();
    float4 c = shadeGlobe(in.normal, color, u);
    return float4(c.rgb * eclipseDim(in.normal, u), c.a) * coverage;
}

// The Moon: a Lambertian-lit sphere (so it shows phases), drawn translated/scaled to its true position via
// the vertex MVP. `normal` is the unit-sphere direction (the Moon's surface normal); its world position is
// `moonCenter + moonRadius·normal`. Darkened and reddened where the Earth eclipses it (lunar eclipse), and
// faded in/out with the map-open animation by `lightFade`.
fragment float4 fragment_moon(GlobeVaryings in [[stage_in]],
                              constant float4 &color [[buffer(0)]],
                              constant GlobeUniforms &u [[buffer(1)]]) {
    float3 n = normalize(in.normal);
    float lit = max(0.0, dot(n, u.sunDirection));   // Lambertian phase: lit hemisphere faces the Sun
    float brightness = mix(0.04, 1.0, lit);          // dark side ~black, a touch of earthshine
    float3 worldPoint = u.moonCenter + u.moonRadius * n;
    float coverage = sunOcclusion(worldPoint, u.sunDirection, float3(0.0), 1.0); // Earth covering the Sun
    float3 shade = mix(float3(1.0), float3(0.25, 0.07, 0.04), coverage); // coppery umbra of a total eclipse
    float3 rgb = color.rgb * brightness * shade;
    float a = color.a * u.lightFade;
    return float4(rgb * a, a);
}
