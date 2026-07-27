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
import Triangulation

/// Orbit camera for the globe. The globe is a unit sphere at the origin and the camera sits on +z looking
/// toward it. `orientation` is the rotation that brings the faced model-space direction, like the connected
/// country's centroid, onto +z. `distance` is how far out the camera sits, smaller being more zoomed in.
/// Only `orientation` and `distance` animate, so the connect transition is a rotation plus a zoom. The
/// orientation is interpolated as a quaternion, which stays well behaved even for near-antipodal
/// country-to-country jumps, where interpolating the target direction instead would collapse through the
/// globe center.
struct GlobeCamera: Equatable {
    /// Default vertical field of view. Also the basis of the zoom-to-fit math.
    static let defaultFieldOfView = Angle.degrees(45)
    private enum Dimensions {
        /// Half-depth of the clip slab centerd on the globe: the unit-sphere radius plus slack, so the near
        /// plane always sits just in front of the visible hemisphere at any camera distance.
        static let clipMargin: Float = 1.5
        /// How far past the globe center the far plane reaches: the celestial radius where the star and sun
        /// billboards sit (a star opposite the camera is roughly that radius plus the camera distance deep),
        /// plus slack that also clears the Moon, which orbits well inside the celestial sphere. Derived, so
        /// raising `celestialRadius` can never silently clip the starfield. There is no depth buffer, so a
        /// distant far plane costs no precision.
        static let farClipMargin: Float = GlobeProjection.celestialRadius + 15
        /// Floor for the near plane, keeping it positive even at the closest camera distance. Small so a
        /// deep zoom right up against the surface, to pull apart close-together location pins, doesn't clip the
        /// near cap of the globe. There is no depth buffer, so a tiny near plane is harmless.
        static let minNearPlane: Float = 0.002
    }

    /// Focal length `1 / tan(fov / 2)`, the vertical scale the perspective matrix is built from and the
    /// basis for the zoom-to-fit math. Defined once so `tan(fov / 2)` lives in one place rather than being
    /// re-spelled at each call site.
    static func focalLength(fieldOfView: Angle = defaultFieldOfView) -> Float {
        1 / tan(Float(fieldOfView.radians) / 2)
    }

    /// Rotation bringing the faced model direction onto +z (north roughly up).
    var orientation: simd_quatf
    /// Camera distance from the globe center (> 1).
    var distance: Float
    /// Vertical field of view.
    var fieldOfView: Angle

    init(orientation: simd_quatf, distance: Float, fieldOfView: Angle = defaultFieldOfView) {
        self.orientation = orientation
        self.distance = distance
        self.fieldOfView = fieldOfView
    }

    /// Model-space direction currently facing the camera: the +z axis brought back into model space.
    /// Used for whole-path back-face culling and for hiding the pin when its location is on the far side.
    var facing: SIMD3<Float> {
        orientation.inverse.act(SIMD3<Float>(0, 0, 1))
    }

    /// Model-to-clip matrix: perspective, view translation, and globe rotation multiplied together.
    ///
    /// The globe is fitted into `framing`'s focus region, but the rest of the render canvas still renders, so the
    /// globe bleeds behind the status bar at the top and spills below the fold at the bottom, unclipped. A focus
    /// region spanning the whole canvas gives a plain full-canvas projection.
    func matrix(framing: GlobeFraming) -> simd_float4x4 {
        let projection = ScreenProjection(fieldOfView: fieldOfView, framing: framing)
        let near = max(Dimensions.minNearPlane, distance - Dimensions.clipMargin)
        let far = distance + Dimensions.farClipMargin
        return projection.matrix(near: near, far: far) * .translation(z: -distance) * simd_float4x4(orientation)
    }

    /// Quaternion bringing `target` onto +z (facing the camera), keeping north roughly up.
    ///
    /// Every rotation has two quaternion encodings, q and -q, and this picks between them from `target`
    /// alone, with no memory of whatever orientation is currently on screen. Interpolating from the
    /// current orientation to a result that landed in the opposite hemisphere rotates the long way round,
    /// so run the result through `aligned(to:)` before animating to it.
    static func orientation(facing target: SIMD3<Float>) -> simd_quatf {
        .lookingAt(target)
    }

    /// Projects a unit-sphere direction to a view-space point, and whether it's on the near hemisphere,
    /// which is what hides a pin when its location rotates to the back of the globe. Takes the already
    /// built `mvp` so the caller doesn't rebuild it per frame.
    func project(_ direction: SIMD3<Float>, mvp: simd_float4x4, viewSize: CGSize) -> (point: CGPoint, isFront: Bool) {
        // Visible only within the horizon cap: a camera at `distance` sees the sphere out to where the line
        // of sight is tangent, so a direction is visible when dot(direction, facing) > 1/distance. A plain
        // "greater than zero" test, the full geometric hemisphere, would let near-limb points show through
        // the globe under perspective, like a pin behind the limb appearing over the front face.
        let isFront = HorizonCap(facing: facing, distance: distance).contains(direction)
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

    /// Inverse of `project`, for direct-manipulation dragging: the unit-sphere point under a screen point,
    /// the surface the finger is touching. In view space, independent of the globe's orientation. Off-globe
    /// points clamp to the nearest point on the limb so a drag that slips off the edge still rotates.
    func unprojectToSphere(_ point: CGPoint, framing: GlobeFraming) -> SIMD3<Float> {
        let projection = ScreenProjection(fieldOfView: fieldOfView, framing: framing)
        return unitSphereHit(ray: projection.viewRay(at: point), cameraDistance: distance)
    }
}
