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

import CoreGraphics
import simd

/// Orbit camera for the globe. The globe is a unit sphere at the origin; the camera sits on +z looking
/// toward it. `orientation` is the rotation that brings the faced model-space direction (e.g. the
/// connected country's centroid) onto +z; `distance` is how far the camera is (smaller = zoomed in).
/// Only `orientation` and `distance` animate, so the connect transition is a shortest-arc rotation +
/// dolly — interpolated as a quaternion (see `AnimatableGlobe`), which stays well-conditioned even for
/// near-antipodal country-to-country jumps where lerping the target direction would collapse through the
/// globe centre.
struct GlobeCamera: Equatable {
    /// Default vertical field of view (radians); shared with the zoom-to-fit maths in `HomeMapView`.
    static let defaultFieldOfView: Float = .pi / 4
    /// Half-depth of the clip slab centred on the globe: the unit-sphere radius (1) plus slack, so the
    /// near and far planes always bracket the visible hemisphere at any dolly distance.
    private static let clipMargin: Float = 1.5
    /// Floor for the near plane, keeping it positive even when dollied in to the closest distance. Small so a
    /// deep zoom (right up against the surface, to pull apart close-together city pins) doesn't clip the near
    /// cap of the globe. There's no depth buffer (back-face culling only), so a tiny near plane is harmless.
    private static let minNearPlane: Float = 0.002

    /// Rotation bringing the faced model direction onto +z (north roughly up).
    var orientation: simd_quatf
    /// Camera distance from the globe centre (> 1).
    var distance: Float
    /// Vertical field of view (radians).
    var fieldOfView: Float

    init(orientation: simd_quatf, distance: Float, fieldOfView: Float = defaultFieldOfView) {
        self.orientation = orientation
        self.distance = distance
        self.fieldOfView = fieldOfView
    }

    /// Model-space direction currently facing the camera: the +z axis brought back into model space.
    /// Used for whole-path back-face culling and for hiding the pin when its location is on the far side.
    var facing: SIMD3<Float> {
        orientation.inverse.act(SIMD3<Float>(0, 0, 1))
    }

    /// Model → clip matrix (perspective × view × globe rotation).
    ///
    /// `viewSize` is the full render canvas; the globe is framed within the sub-region
    /// `[focusTop, focusTop + focusHeight]` of it. The rest of the canvas (above `focusTop` and below the
    /// focus region) still renders the globe, so it bleeds behind the notch at the top and spills below
    /// the fold at the bottom, un-clipped (the old map's "peek"). `focusTop == 0 && focusHeight == height`
    /// ⇒ a plain full-canvas projection.
    func matrix(viewSize: CGSize, focusHeight: CGFloat, focusTop: CGFloat = 0) -> simd_float4x4 {
        let height = Float(max(viewSize.height, 1))
        let projection = Self.perspective(
            fovy: fieldOfView,
            width: Float(max(viewSize.width, 1)),
            renderHeight: height,
            focusHeight: Float(min(max(focusHeight, 1), CGFloat(height))),
            focusTop: Float(min(max(focusTop, 0), CGFloat(height))),
            near: max(Self.minNearPlane, distance - Self.clipMargin),
            far: distance + Self.clipMargin
        )
        return projection * Self.translation(z: -distance) * simd_float4x4(orientation)
    }

    /// Quaternion bringing `target` onto +z (facing the camera), keeping north roughly up. Note the sign
    /// is canonical to the rotation, not to any previous orientation — callers that animate between
    /// orientations must hemisphere-align consecutive quaternions themselves (see `HomeMapView`).
    static func orientation(facing target: SIMD3<Float>) -> simd_quatf {
        let forward = simd_normalize(target)
        var worldUp = SIMD3<Float>(0, 1, 0)
        if abs(simd_dot(forward, worldUp)) > 0.999 { worldUp = SIMD3<Float>(0, 0, 1) }
        let right = simd_normalize(simd_cross(worldUp, forward))
        let up = simd_cross(forward, right)
        // Rows (right, up, forward) map model directions into the view frame.
        return simd_quatf(simd_float3x3(rows: [right, up, forward]))
    }

    /// Projects a unit-sphere direction to a view-space point, and whether it's on the near hemisphere
    /// (for hiding the pin when its location rotates to the back of the globe). Takes the already-built
    /// `mvp` (from `matrix(viewSize:focusHeight:focusTop:)`) so the caller doesn't rebuild it per frame.
    func project(_ direction: SIMD3<Float>, mvp: simd_float4x4, viewSize: CGSize) -> (point: CGPoint, isFront: Bool) {
        // Visible only within the horizon cap: a camera at `distance` sees the sphere out to where the line
        // of sight is tangent — angular radius acos(1/distance), i.e. dot(direction, facing) > 1/distance.
        // A plain `> 0` (the full geometric hemisphere) lets near-limb points show "through" the globe under
        // perspective (e.g. a pin behind the limb appearing over the front face).
        let isFront = simd_dot(simd_normalize(direction), facing) > 1 / distance
        let clip = mvp * SIMD4<Float>(direction, 1)
        guard clip.w > 0 else { return (.zero, false) }
        let ndcX = clip.x / clip.w
        let ndcY = clip.y / clip.w
        let point = CGPoint(
            x: (CGFloat(ndcX) * 0.5 + 0.5) * viewSize.width,
            y: (1 - (CGFloat(ndcY) * 0.5 + 0.5)) * viewSize.height
        )
        return (point, isFront)
    }

    /// Inverse of `project` for direct-manipulation dragging: the unit-sphere point (in **view space**,
    /// independent of the globe's orientation) under a screen point — i.e. the surface the finger is
    /// touching. Off-globe points clamp to the nearest point on the limb so a drag that slips off the edge
    /// still rotates. `focusHeight`/`focusTop` must match what was passed to `matrix`.
    func unprojectToSphere(_ point: CGPoint, viewSize: CGSize, focusHeight: CGFloat, focusTop: CGFloat) -> SIMD3<Float> {
        let width = Float(max(viewSize.width, 1))
        let renderHeight = Float(max(viewSize.height, 1))
        let fh = Float(min(max(focusHeight, 1), CGFloat(renderHeight)))
        let ft = Float(min(max(focusTop, 0), CGFloat(renderHeight)))
        let ysBase = 1 / tan(fieldOfView * 0.5)
        let xs = ysBase * fh / width
        let ys = ysBase * fh / renderHeight
        let yOffset = (fh + 2 * ft) / renderHeight - 1
        let ndcX = Float(point.x / viewSize.width) * 2 - 1
        let ndcY = 1 - Float(point.y / viewSize.height) * 2
        // View-space ray from the camera (at the origin, looking down −z); inverts `perspective`.
        let direction = simd_normalize(SIMD3<Float>(ndcX / xs, (ndcY + yOffset) / ys, -1))
        // Intersect the unit sphere centred at (0, 0, −distance).
        let toCentre = SIMD3<Float>(0, 0, distance) // origin − centre
        let dDotL = simd_dot(direction, toCentre)
        let discriminant = dDotL * dDotL - (distance * distance - 1)
        let t = discriminant >= 0 ? -dDotL - sqrt(discriminant) : -dDotL // near hit, else perpendicular foot
        let hit = direction * t
        return simd_normalize(hit - SIMD3<Float>(0, 0, -distance))
    }

    // MARK: - Matrix helpers

    /// Frames the globe within `[focusTop, focusTop + focusHeight]` of a `renderHeight`-tall canvas: the y
    /// output is compressed by `m = focusHeight/renderHeight` and shifted so the image a `focusHeight`-tall
    /// view would show lands in that band, and the globe continues above/below it un-clipped. Horizontal
    /// scale matches a `focusHeight`-tall view, so pixels stay square.
    private static func perspective(
        fovy: Float,
        width: Float,
        renderHeight: Float,
        focusHeight: Float,
        focusTop: Float,
        near: Float,
        far: Float
    ) -> simd_float4x4 {
        let ysBase = 1 / tan(fovy * 0.5)
        let m = focusHeight / renderHeight
        let xs = ysBase * focusHeight / width
        let ys = ysBase * m
        let yOffset = (focusHeight + 2 * focusTop) / renderHeight - 1
        let zs = far / (near - far) // Metal clip-z in [0, 1], right-handed (looking down −z)
        return simd_float4x4(columns: (
            SIMD4<Float>(xs, 0, 0, 0),
            SIMD4<Float>(0, ys, 0, 0),
            SIMD4<Float>(0, yOffset, zs, -1),
            SIMD4<Float>(0, 0, zs * near, 0)
        ))
    }

    private static func translation(z: Float) -> simd_float4x4 {
        simd_float4x4(columns: (
            SIMD4<Float>(1, 0, 0, 0),
            SIMD4<Float>(0, 1, 0, 0),
            SIMD4<Float>(0, 0, 1, 0),
            SIMD4<Float>(0, 0, z, 1)
        ))
    }
}
