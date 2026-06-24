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

import CoreGraphics
import simd
import Triangulation

/// The globe's off-centre perspective framing. It owns the projection scales in one place, the focal
/// length, the horizontal and vertical clip-space scales, and the framed region's offset, and derives both
/// the forward matrix and its inverse (a screen point back to a view-space ray) from them, so the two can
/// never drift apart.
///
/// The globe is framed within `[focusTop, focusTop + focusHeight]` of the taller render canvas and spills
/// above and below it unclipped. Stays here in the Map folder rather than in `Triangulation` because it is
/// tied to `CGSize`, to the app's framing, and to Metal's clip conventions.
struct ScreenProjection {
    let viewSize: CGSize
    /// Vertical clip-space scale: the focal length compressed into the framed region.
    private let yScale: Float
    /// Horizontal clip-space scale, sized so pixels stay square against a `focusHeight`-tall view.
    private let xScale: Float
    /// Vertical shift placing the framed region within the full canvas.
    private let yOffset: Float

    init(fieldOfView: Angle, viewSize: CGSize, focusHeight: CGFloat, focusTop: CGFloat = 0) {
        let width = Float(max(viewSize.width, 1))
        let renderHeight = Float(max(viewSize.height, 1))
        let fh = Float(min(max(focusHeight, 1), CGFloat(renderHeight)))
        let ft = Float(min(max(focusTop, 0), CGFloat(renderHeight)))
        let focal = GlobeCamera.focalLength(fieldOfView: fieldOfView) // 1 / tan(fov / 2)
        self.viewSize = viewSize
        self.xScale = focal * fh / width
        self.yScale = focal * fh / renderHeight
        self.yOffset = (fh + 2 * ft) / renderHeight - 1
    }

    /// Perspective matrix. The caller multiplies in the view translation and globe rotation. The y output
    /// is compressed into the framed region and the image continues above and below it unclipped.
    func matrix(near: Float, far: Float) -> simd_float4x4 {
        let zs = far / (near - far) // Metal clip z in [0, 1], right-handed, looking down -z
        return simd_float4x4(columns: (
            SIMD4<Float>(xScale, 0, 0, 0),
            SIMD4<Float>(0, yScale, 0, 0),
            SIMD4<Float>(0, yOffset, zs, -1),
            SIMD4<Float>(0, 0, zs * near, 0)
        ))
    }

    /// View-space ray through a screen point, from the camera at the origin looking down -z. The exact
    /// inverse of `matrix`'s framing, built from the same scales. The caller intersects it with the globe.
    func viewRay(at point: CGPoint) -> SIMD3<Float> {
        let ndcX = Float(point.x / viewSize.width) * 2 - 1
        let ndcY = 1 - Float(point.y / viewSize.height) * 2
        return simd_normalize(SIMD3<Float>(ndcX / xScale, (ndcY + yOffset) / yScale, -1))
    }
}

/// First hit of a view-space `ray`, cast from the camera at the origin, on the unit globe whose centre sits
/// `cameraDistance` ahead down -z. A ray that misses the globe clamps to the nearest point on the limb, so
/// a drag that slips off the edge still rotates rather than jumping. Returns the hit as a unit-sphere
/// direction relative to the globe centre.
func unitSphereHit(ray direction: SIMD3<Float>, cameraDistance distance: Float) -> SIMD3<Float> {
    let toCentre = SIMD3<Float>(0, 0, distance) // origin minus centre
    let dDotL = simd_dot(direction, toCentre)
    let discriminant = dDotL * dDotL - (distance * distance - 1)
    let t = discriminant >= 0 ? -dDotL - sqrt(discriminant) : -dDotL // near hit, else the perpendicular foot
    let hit = direction * t
    return simd_normalize(hit - SIMD3<Float>(0, 0, -distance))
}
