//
//  Created on 30.06.2026 by John Biggs.
//
//  Copyright (c) 2026 Proton AG
//
//  Proton VPN is free software: you can redistribute it and/or modify
//  it under the terms of the GNU General Public License as published by
//  the Free Software Foundation, either version 3 of the License, or
//  (at your option) any later version.
//
//  Proton VPN is distributed in the hope that it will be useful,
//  but WITHOUT ANY WARRANTY; without even the implied warranty of
//  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
//  GNU General Public License for more details.
//
//  You should have received a copy of the GNU General Public License
//  along with Proton VPN.  If not, see <https://www.gnu.org/licenses/>.

import simd

/// The visible spherical cap of the globe seen from a finite camera distance. A camera `distance` from the unit sphere
/// sees it out to where the line of sight is tangent, an angular radius of `acos(1/distance)`, so a direction `d` is
/// visible when `dot(d, facing) > 1/distance`. Anything past that rim is hidden behind the limb. A plain "greater than
/// zero" test, the full geometric hemisphere, would let near-limb points show through the globe under perspective.
/// Naming this puts the `1/distance` threshold, used to hide far-side pins on the CPU and shipped to the GPU point and
/// star culls, in one place instead of being re-derived at each site.
public struct HorizonCap: Sendable {
    /// Model-space direction the camera faces (the cap's centre).
    public let facing: SIMD3<Float>
    /// Camera distance from the globe centre (greater than 1).
    public let distance: Float

    public init(facing: SIMD3<Float>, distance: Float) {
        self.facing = facing
        self.distance = distance
    }

    /// The cosine threshold a direction's dot with `facing` must exceed to be on the near side: `1/distance`. This is
    /// the single scalar handed to the GPU pin and star culls, so the shader never re-derives the reciprocal per
    /// vertex. Clamped for a degenerate `distance` of 1 or less (camera on or inside the sphere): nothing is visible
    /// and `angularRadius` stays 0 instead of going NaN through the `acos` of a value above 1.
    public var cosThreshold: Float {
        1 / max(distance, 1)
    }

    /// Half-angle of the visible cap.
    public var angularRadius: Angle {
        .acos(Double(cosThreshold))
    }

    /// Whether `direction` (assumed unit) is on the visible near side of the globe.
    public func contains(_ direction: SIMD3<Float>) -> Bool {
        cosAngle(between: direction, facing) > cosThreshold
    }
}
