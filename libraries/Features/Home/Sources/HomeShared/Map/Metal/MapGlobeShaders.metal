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

// Globe shaders. The map is on a unit sphere, projected by a single MVP built from the perspective, view,
// and globe rotation. Hemisphere occlusion is handled by back-face culling: back-hemisphere triangles face
// away, so the far side is simply never drawn.

#include <metal_stdlib>
// Shared CPU and GPU struct layouts (MapUniforms, PinUniforms, the star and sun uniforms). The file lives
// once in the `MapShaderTypes` C module, which Swift imports. It's included by relative path here because
// SPM adds that module's header directory to the Swift and clang search paths but not the Metal compiler's,
// so the angle-bracket form isn't found.
#include "../../../MapShaderTypes/include/MapShaderTypes.h"
using namespace metal;

// MARK: - Shared constants

// Radius the celestial bodies (stars, sun) sit at. Far enough that the camera's small dolly range gives
// negligible parallax, so they read as fixed at infinity. Mirrors `GlobeProjection.celestialRadius` on the
// Swift side.
constant float celestialRadius = 100.0;
// The Sun's angular radius as seen from Earth, in radians. Mirrors `CelestialConstants.sunAngularRadius`
// on the Swift side.
constant float sunAngularRadius = 0.00465;
// A vertex parked outside the clip box on every axis, so the rasterizer discards its whole primitive. This
// is how a billboard behind the camera or past the globe's horizon is culled, since there is no depth
// buffer.
constant float4 culledVertex = float4(2.0, 2.0, 2.0, 1.0);

// The globe's look tuning, named here rather than inline at each formula:
constant float nightShade = 0.85;     // globe brightness on the night side (shadeGlobe)
constant float fullSunShade = 1.4;    // globe brightness at the subsolar point (shadeGlobe)
constant float moonEarthshine = 0.04; // Moon dark-side brightness, a hint of earthshine (fragment_moon)
constant float3 lunarUmbraColor = float3(0.25, 0.07, 0.04); // coppery total-eclipse umbra (fragment_moon)

// Premultiplied-alpha output for the globe's (one, 1 - srcAlpha) blend over the transparent drawable: the
// stored RGB is color times alpha, so soft and faded edges composite correctly. The fragments return
// through here.
static float4 premultiply(float3 rgb, float alpha) {
    return float4(rgb * alpha, alpha);
}

// The border-segment instance layout (`MapGlobeSegment`) comes from MapShaderTypes.h with the uniforms.
// It is the same struct the app bulk-loads from `world-globe.bin`, so the two sides can't drift.

// Surface normal (equal to the model-space unit-sphere position) carried to the fragment so it can shade
// the globe by the sun direction.
struct GlobeVaryings {
    float4 position [[position]];
    float3 normal;
};

// Border vertices additionally carry their position within the segment ribbon, so the fragment can round
// the cap into a capsule. `local` holds the signed distances along the segment from `a` and across it.
// `segLength` is the segment length, for clamping the along-distance to the core.
struct BorderVaryings {
    float4 position [[position]];
    float3 normal;
    float2 local;
    float segLength;
};

// Fraction of the Sun's disc covered by a sphere occluder (centre `occCenter`, radius `occRadius` in Earth
// radii) as seen from `point`, with the Sun in the effectively parallel direction `sunDir`. 0 means the
// Sun is clear, 1 fully covered. This is the whole eclipse calculation: the Earth dims where the Moon
// covers the Sun, and the Moon darkens where the Earth covers it. Evaluated per fragment, so the Moon's
// parallax lands the shadow on the right part of the globe.
static float sunOcclusion(float3 point, float3 sunDir, float3 occCenter, float occRadius) {
    if (occRadius <= 0.0) return 0.0;
    float3 toOcc = occCenter - point;
    float dist = length(toOcc);
    if (dist < 1e-4) return 0.0;
    float3 occDir = toOcc / dist;
    if (dot(occDir, sunDir) <= 0.0) return 0.0; // the occluder must lie toward the Sun
    const float rSun = sunAngularRadius;        // the Sun's angular radius (radians)
    float rOcc = occRadius / dist;              // the occluder's angular radius from here
    float sep = acos(clamp(dot(occDir, sunDir), -1.0, 1.0));
    // Ramp across the penumbra: first contact at sep = rSun + rOcc, total at sep = abs(rSun - rOcc).
    // Capped by the occluder's disc-area ratio so an annular eclipse, where the Moon looks smaller than
    // the Sun, never fully covers it.
    float coverage = clamp((rSun + rOcc - sep) / (2.0 * rSun), 0.0, 1.0);
    return min(coverage, min(1.0, (rOcc * rOcc) / (rSun * rSun)));
}

// Shared globe shading for fills and borders: diffuse sunlight added to the day side, tinted with the
// connection color, and faded in by `lightFade`. A solar eclipse scales the sunlight itself, before the
// day/night mix, so a fully shadowed point shades exactly like night, never darker, and a partial shadow
// crossing the day/night line blends into it with no visible edge.
// Premultiplied for the (one, 1 - srcAlpha) blend over the transparent drawable.
static float4 shadeGlobe(float3 normal, float4 color, constant MapUniforms &u) {
    float3 n = normalize(normal);
    float visibleSun = 1.0 - sunOcclusion(n, u.sunDirection, u.moonCenter, u.moonRadius);
    float lambert = max(0.0, dot(n, u.sunDirection)) * visibleSun;
    float lit = lambert * u.lightFade;              // day-side intensity, faded in with the map open
    float shade = mix(nightShade, fullSunShade, lambert);
    float factor = mix(1.0, shade, u.lightFade);
    float3 rgb = color.rgb * factor + u.sunTint * (u.tintStrength * lit);
    return premultiply(rgb, color.a);
}

// MARK: - Billboard + soft-edge helpers

// Unit-quad corner for triangle-strip vertex `vid` (0 through 3): x and y each -1 or +1.
static float2 stripCorner(uint vid) {
    return float2((vid & 1) == 0 ? -1.0 : 1.0, vid < 2 ? -1.0 : 1.0);
}

// Perspective-correct billboard expansion: the clip-space xy offset that grows a point into a quad of
// `halfExtent` pixels along `corner`, a constant on-screen size at any depth (the `* w` cancels the
// perspective divide). Shared by the city-point, star, and sun passes.
static float2 billboardOffset(float2 corner, float halfExtent, float2 viewport, float w) {
    return corner * halfExtent * (2.0 / viewport) * w;
}

// Antialiased coverage of a soft edge: 1 inside, ramping to 0 across about a pixel (`aa`, from fwidth)
// centred on `edge`. Shared by the point, star, and border fragments.
static float softCoverage(float dist, float edge, float aa) {
    return clamp((edge - dist) / aa + 0.5, 0.0, 1.0);
}

// Fills (and the base ocean sphere): positions are unit-sphere points, which are also the surface normals.
vertex GlobeVaryings vertex_globe_fill(const device float3 *positions [[buffer(0)]],
                                       constant MapUniforms &u [[buffer(1)]],
                                       uint vid [[vertex_id]]) {
    GlobeVaryings out;
    out.position = u.mvp * float4(positions[vid], 1.0);
    out.normal = positions[vid];
    return out;
}

// Borders: instanced ribbon expansion on the sphere. Each segment becomes a quad in the local tangent
// plane, offset perpendicular to both the segment direction and the surface normal (the endpoint itself)
// via cross products, and extended by a full `halfWidth` cap at each end. The fragment rounds that cap
// into a capsule, so a short segment becomes a dot and adjacent segments' round caps meet in a smooth
// round join, where a square cap's corners would poke out past the joint.
vertex BorderVaryings vertex_globe_border(const device MapGlobeSegment *segs [[buffer(0)]],
                                          constant MapUniforms &u [[buffer(1)]],
                                          uint vid [[vertex_id]],
                                          uint iid [[instance_id]]) {
    MapGlobeSegment s = segs[iid];
    float3 delta = s.b - s.a;
    float len = length(delta);
    float3 dir = len > 1e-9 ? delta / len : float3(1.0, 0.0, 0.0);
    float halfWidth = u.borderHalfWidth;
    float outer = halfWidth * 1.5; // quad a touch wider than the stroke, so the edge AA has room on both sides

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

// Fill fragment, also used by the base ocean sphere: the shared sun shading, which includes any solar
// eclipse. Premultiplied for the (one, 1 - srcAlpha) blend.
fragment float4 fragment_solid(GlobeVaryings in [[stage_in]],
                               constant float4 &color [[buffer(0)]],
                               constant MapUniforms &u [[buffer(1)]]) {
    return shadeGlobe(in.normal, color, u);
}

// Border fragment: rounds the square cap into a capsule. `dist` is the distance from the segment's clamped
// core line to this pixel. Coverage falls from 1 to 0 across the `halfWidth` edge over about a pixel, so
// the rounded cap and join are smoothly antialiased rather than cut off hard, which would alias.
// Premultiplied by coverage so the soft edge composites correctly.
fragment float4 fragment_globe_border(BorderVaryings in [[stage_in]],
                                      constant float4 &color [[buffer(0)]],
                                      constant MapUniforms &u [[buffer(1)]]) {
    float along = clamp(in.local.x, 0.0, in.segLength);     // nearest point on the core segment
    float dist = length(float2(in.local.x - along, in.local.y));
    float aa = max(fwidth(dist), 1e-6);
    float coverage = softCoverage(dist, u.borderHalfWidth, aa); // edge centred on halfWidth, a pixel of AA
    if (coverage <= 0.0) discard_fragment();
    return shadeGlobe(in.normal, color, u) * coverage;
}

// The Moon: a Lambert-lit sphere, so it shows phases, drawn translated and scaled to its true position via
// the vertex MVP. `normal` is the unit-sphere direction, the Moon's surface normal, and its world position
// is `moonCenter + moonRadius * normal`. Darkened and reddened where the Earth eclipses it, and faded with
// the map-open animation by `lightFade`.
fragment float4 fragment_moon(GlobeVaryings in [[stage_in]],
                              constant float4 &color [[buffer(0)]],
                              constant MapUniforms &u [[buffer(1)]]) {
    float3 n = normalize(in.normal);
    float lit = max(0.0, dot(n, u.sunDirection));   // Lambertian phase: lit hemisphere faces the Sun
    float brightness = mix(moonEarthshine, 1.0, lit); // dark side near black, a touch of earthshine
    float3 worldPoint = u.moonCenter + u.moonRadius * n;
    float coverage = sunOcclusion(worldPoint, u.sunDirection, float3(0.0), 1.0); // Earth covering the Sun
    float3 shade = mix(float3(1.0), lunarUmbraColor, coverage); // coppery umbra of a total eclipse
    float3 rgb = color.rgb * brightness * shade;
    float a = color.a * u.lightFade;
    return premultiply(rgb, a);
}

// MARK: - City points

// The location dots are drawn in the globe's own render pass rather than a SwiftUI overlay, so they can't
// lag behind the sphere under a fast drag. Each is an instanced screen-facing billboard, with the
// `PinUniforms` layout coming from MapShaderTypes.h.
struct PinVaryings {
    float4 position [[position]];
    float2 local; // pixel offset from the dot centre, for the circle edge
};

// One screen-facing quad per city point, a constant pixel size regardless of zoom, projected by the
// globe's own MVP. Points past the visible horizon are collapsed off-screen: there is no depth buffer, so
// a dot behind the limb would otherwise draw over the front face. The same cap the CPU-side projection
// applies.
vertex PinVaryings vertex_pin(const device float3 *positions [[buffer(0)]],
                              constant PinUniforms &u [[buffer(1)]],
                              uint vid [[vertex_id]],
                              uint iid [[instance_id]]) {
    float3 dir = normalize(positions[iid]);
    PinVaryings out;
    if (dot(dir, u.cameraTarget) <= u.horizonCosThreshold) { // past the horizon cap
        out.position = culledVertex;
        out.local = float2(0.0);
        return out;
    }
    float4 clip = u.mvp * float4(dir, 1.0);
    float2 corner = stripCorner(vid);
    float halfExtent = u.diameter * 0.5 + 2.0;               // room for the white stroke + AA
    out.local = corner * halfExtent;
    clip.xy += billboardOffset(corner, halfExtent, u.viewportSize, clip.w); // constant pixel size
    out.position = clip;
    return out;
}

// A grey dot with a soft white rim: the in-motion city point. The larger settled SwiftUI discs take over
// once the map is still. Coverage-premultiplied for the (one, 1 - srcAlpha) blend, antialiased via
// `fwidth`.
fragment float4 fragment_pin(PinVaryings in [[stage_in]],
                             constant PinUniforms &u [[buffer(1)]]) {
    float r = length(in.local);                                     // pixels from the centre
    float aa = max(fwidth(r), 1e-6);
    float fillR = u.diameter * 0.5;                                 // grey fill radius
    float coverage = softCoverage(r, fillR + 0.5, aa);              // out to the stroke's outer edge
    if (coverage <= 0.0) discard_fragment();
    float rim = (1.0 - smoothstep(0.0, 1.0, abs(r - fillR))) * 0.7; // white ring centred on the fill edge
    float3 rgb = mix(u.fillColor.rgb, float3(1.0), rim);
    float alpha = coverage * u.fade * u.fillColor.a;
    return premultiply(rgb, alpha);
}

// MARK: - Sky glow (Milky Way)

// A continuous diffuse band, not billboards: a fullscreen triangle whose fragment shader reconstructs each
// pixel's model-space view ray and paints an FBM-textured Gaussian around the galactic plane. Because it is
// evaluated per pixel there are no discrete elements to resolve as discs, which is what discrete sprites
// can't avoid at these densities. Drawn first of all, so the stars, Moon, and opaque Earth cover it.

// Band half-width as the standard deviation of sin(galactic latitude); ~0.075 is a band about 4.3 degrees
// to a side, widened past that by the Gaussian's own tails into a defined river rather than a broad wash.
constant float glowSigma = 0.075;
// Spatial frequency of the cloud texture: higher is finer filaments.
constant float glowCloudFrequency = 7.0;
// Floor on the cloud term, so dark dust lanes dim the band without ever cutting it fully.
constant float glowLaneFloor = 0.3;
// Overall strength of the haze before the zoom-out fade. Deliberately low: the band is a backdrop and must
// not pull attention off the globe, which is the subject.
constant float glowIntensity = 0.3;
// Slightly cool white, the tint of unresolved starlight.
constant float3 glowTint = float3(0.82, 0.87, 1.0);
// Low-frequency meander of the band's centreline, so it isn't a geometrically perfect great circle: the
// real Milky Way bulges and dips along its length. Amplitude is in sin(galactic-latitude) units, so ~0.045
// is about 2.6 degrees; the low frequency keeps the whole ribbon shifting coherently rather than making its
// edges wavy.
constant float glowWarpFrequency = 1.8;
constant float glowWarpAmplitude = 0.045;
// Lattice offset decorrelating the warp's noise sample from the cloud FBM below, which shares the noise
// function; without it the centreline would bend wherever the clouds brighten.
constant float3 glowWarpDecorrelation = float3(37.0);
// Band tail below which the fragment is discarded outright, skipping the noise work over most of the sky.
constant float glowTailCutoff = 0.003;
// Contrast stretch applied to the raw FBM (gain, then bias, then clamp): hard enough that filaments and
// dark rifts read as structure without the peaks blowing hot.
constant float glowCloudGain = 1.8;
constant float glowCloudBias = -0.42;
// Brightness at the anticentre relative to the galactic-centre end, and the window (in dot-with-centre
// units) the lift smoothsteps over.
constant float glowAnticentreLevel = 0.55;
constant float2 glowCentreWindow = float2(-0.4, 1.0);

// Hash of an integer lattice point to [0, 1). Cheap and stable, enough for a soft cloud field.
static float glowHash(float3 p) {
    p = fract(p * 0.3183099 + 0.1);
    p *= 17.0;
    return fract(p.x * p.y * p.z * (p.x + p.y + p.z));
}

// Trilinearly interpolated value noise with a quintic fade, roughly [0, 1], features about one unit across.
static float glowValueNoise(float3 x) {
    float3 i = floor(x);
    float3 f = fract(x);
    f = f * f * f * (f * (f * 6.0 - 15.0) + 10.0);
    float n000 = glowHash(i + float3(0, 0, 0));
    float n100 = glowHash(i + float3(1, 0, 0));
    float n010 = glowHash(i + float3(0, 1, 0));
    float n110 = glowHash(i + float3(1, 1, 0));
    float n001 = glowHash(i + float3(0, 0, 1));
    float n101 = glowHash(i + float3(1, 0, 1));
    float n011 = glowHash(i + float3(0, 1, 1));
    float n111 = glowHash(i + float3(1, 1, 1));
    float x00 = mix(n000, n100, f.x);
    float x10 = mix(n010, n110, f.x);
    float x01 = mix(n001, n101, f.x);
    float x11 = mix(n011, n111, f.x);
    return mix(mix(x00, x10, f.y), mix(x01, x11, f.y), f.z);
}

// Four octaves of value noise: the cloud/dust structure along the band.
static float glowFBM(float3 x) {
    float sum = 0.0;
    float amplitude = 0.5;
    for (int octave = 0; octave < 4; octave++) {
        sum += amplitude * glowValueNoise(x);
        x *= 2.0;
        amplitude *= 0.5;
    }
    return sum;
}

struct SkyGlowVaryings {
    float4 position [[position]];
    float4 farPoint; // homogeneous model-space far point, divided per fragment to recover the view ray
};

vertex SkyGlowVaryings vertex_skyglow(constant SkyGlowUniforms &u [[buffer(0)]], uint vid [[vertex_id]]) {
    // The one and only definition of the fullscreen triangle's corners: the far points derive from them
    // through the inverse matrix right here, so position and view ray can never disagree.
    float2 clip[3] = { float2(-1.0, -1.0), float2(3.0, -1.0), float2(-1.0, 3.0) }; // covers the screen
    SkyGlowVaryings out;
    out.position = float4(clip[vid], 0.5, 1.0); // z is arbitrary; there is no depth buffer
    out.farPoint = u.inverseMVP * float4(clip[vid], 1.0, 1.0); // far-plane point, homogeneous
    return out;
}

fragment float4 fragment_skyglow(SkyGlowVaryings in [[stage_in]], constant SkyGlowUniforms &u [[buffer(0)]]) {
    float3 dir = normalize(in.farPoint.xyz / in.farPoint.w - u.cameraPosition);

    // Meander the centreline: shift the effective latitude by a low-frequency noise sampled along the band,
    // so the ribbon wanders instead of tracing a perfect great circle.
    float warp = (glowValueNoise(dir * glowWarpFrequency + glowWarpDecorrelation) - 0.5) * 2.0 * glowWarpAmplitude;

    // Gaussian in the warped galactic latitude: the band's cross-profile is smooth by construction.
    float sinLatitude = dot(dir, u.pole) - warp;
    float band = exp(-(sinLatitude * sinLatitude) / (2.0 * glowSigma * glowSigma));
    if (band < glowTailCutoff) discard_fragment();

    // FBM along the band supplies clouds and dark lanes.
    float clouds = clamp(glowFBM(dir * glowCloudFrequency) * glowCloudGain + glowCloudBias, 0.0, 1.0);
    float lane = glowLaneFloor + (1.0 - glowLaneFloor) * clouds;

    // Brighter toward the galactic centre, dimmer toward the anticentre, as the real band is.
    float toCentre = dot(dir, u.centre);
    float centreLift = glowAnticentreLevel + (1.0 - glowAnticentreLevel) * smoothstep(glowCentreWindow.x, glowCentreWindow.y, toCentre);

    float glow = band * lane * centreLift * glowIntensity * u.fade;
    return premultiply(glowTint, glow);
}

// MARK: - Stars

// The starfield is drawn in the globe's own pass rather than a SwiftUI overlay, so it can't lag behind the
// globe under a fast drag. Each star is an instanced screen-facing billboard placed far out at the
// celestial radius and projected by the same MVP, so the field turns with the camera. Drawn first, so the
// opaque Moon and globe cover the stars behind them. The camera's far plane is pushed past the celestial
// radius so the GPU doesn't clip them. The `StarInstance` and `StarUniforms` layouts come from
// MapShaderTypes.h.

struct StarVaryings {
    float4 position [[position]];
    float2 local;    // pixel offset from the dot centre
    float radiusPx;  // this star's radius in pixels
    float brightness; // base alpha, with the overall fade already folded in
};

vertex StarVaryings vertex_star(const device StarInstance *stars [[buffer(0)]],
                                constant StarUniforms &u [[buffer(1)]],
                                uint vid [[vertex_id]],
                                uint iid [[instance_id]]) {
    StarInstance s = stars[iid];
    float4 clip = u.mvp * float4(s.direction * celestialRadius, 1.0);
    StarVaryings out;
    if (clip.w <= 1e-4) { // behind the camera
        out.position = culledVertex;
        out.local = float2(0.0);
        out.radiusPx = 0.0;
        out.brightness = 0.0;
        return out;
    }
    float radiusPx = s.radius * u.scale;
    float halfExtent = radiusPx + 1.0; // room for the AA fringe
    float2 corner = stripCorner(vid);
    out.local = corner * halfExtent;
    clip.xy += billboardOffset(corner, halfExtent, u.viewportSize, clip.w); // constant pixel size
    out.position = clip;
    out.radiusPx = radiusPx;
    out.brightness = s.brightness * u.fade; // fold the overall fade in here so the fragment needs no uniform
    return out;
}

// A crisp white pinpoint, antialiased via `fwidth` and premultiplied for the (one, 1 - srcAlpha) blend.
// The Milky Way's diffuse light is the sky-glow pass above, not a star variant, so no softness knob here.
fragment float4 fragment_star(StarVaryings in [[stage_in]]) {
    float r = length(in.local);
    float aa = max(fwidth(r), 1e-6);
    float coverage = softCoverage(r, in.radiusPx, aa);
    if (coverage <= 0.0) discard_fragment();
    float alpha = in.brightness * coverage;
    return premultiply(float3(1.0), alpha); // white
}

// MARK: - Sun

// The sun: a single soft-glow billboard at the sub-solar direction, placed at the celestial radius and
// projected by the same MVP, so it turns with the camera. Drawn after the stars but before the Moon and
// globe, so the opaque sphere occludes it and the glow only shows once it has swung past the limb to the
// night side. The `SunUniforms` layout comes from MapShaderTypes.h.
struct SunVaryings {
    float4 position [[position]];
    float2 local; // quad coordinates from -1 to 1, for the radial gradient
};

vertex SunVaryings vertex_sun(constant SunUniforms &u [[buffer(0)]], uint vid [[vertex_id]]) {
    float3 dir = normalize(u.sunDirection);
    SunVaryings out;
    float4 clip = u.mvp * float4(dir * celestialRadius, 1.0);
    if (clip.w <= 1e-4) { // behind the camera
        out.position = culledVertex;
        out.local = float2(0.0);
        return out;
    }
    float2 corner = stripCorner(vid);
    out.local = corner;
    clip.xy += billboardOffset(corner, u.radiusPixels, u.viewportSize, clip.w);
    out.position = clip;
    return out;
}

// Radial glow: a white core fading through the connection tint to clear at the edge. Premultiplied.
fragment float4 fragment_sun(SunVaryings in [[stage_in]], constant SunUniforms &u [[buffer(0)]]) {
    float r = length(in.local); // 0 at the centre, 1 at the edge
    if (r >= 1.0) discard_fragment();
    float3 color;
    float alpha;
    if (r < 0.5) {
        float t = r / 0.5;
        color = mix(float3(1.0), u.color, t); // white core into the tint
        alpha = mix(0.95, 0.7, t);
    } else {
        float t = (r - 0.5) / 0.5;
        color = u.color;
        alpha = mix(0.7, 0.0, t); // tint out to clear
    }
    alpha *= u.fade;
    return premultiply(color, alpha);
}
