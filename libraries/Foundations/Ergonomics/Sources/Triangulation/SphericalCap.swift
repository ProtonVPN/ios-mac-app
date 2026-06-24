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

/// A spherical cap: every unit-sphere direction within `radius` of `center`. Names the centroid plus
/// enclosing angular radius pair the globe leans on for framing. Zooming to fit a country or a cluster of
/// pins means finding the cap that bounds the points, then backing the camera up until it fills the view.
public struct SphericalCap: Sendable, Equatable {
    /// Unit direction to the cap's centre.
    public let center: SIMD3<Float>
    /// Half-angle from `center` to the rim.
    public let radius: Angle

    public init(center: SIMD3<Float>, radius: Angle) {
        self.center = center
        self.radius = radius
    }
}

public extension SphericalCap {
    /// The cap covering `directions`: the centre is their normalised mean direction, and the radius reaches
    /// the farthest member from it. Frames a cluster of pins around its own centroid. Empty input gives a
    /// zero cap facing +z. A balanced or antipodal set, whose mean is zero and has no meaningful centre,
    /// falls back to the first member as the centre rather than letting `normalize(0)` poison the cap
    /// with NaNs.
    static func enclosing(_ directions: [SIMD3<Float>]) -> SphericalCap {
        guard !directions.isEmpty else {
            return SphericalCap(center: SIMD3<Float>(0, 0, 1), radius: .radians(0))
        }
        let sum = directions.reduce(SIMD3<Float>(repeating: 0), +)
        let length = simd_length(sum)
        let center = length > 1e-6 ? sum / length : directions[0]
        let radius = directions.map { angle(between: center, $0) }.max() ?? .radians(0)
        return SphericalCap(center: center, radius: radius)
    }

    /// A cap on a caller-chosen `center`, grown to enclose every cap in `caps`. The centre is the caller's
    /// because a good one isn't always the vertex mean: a country's bounding-box centre avoids the poleward
    /// bias the mean picks up over a wide longitude span.
    static func enclosing(_ caps: [SphericalCap], around center: SIMD3<Float>) -> SphericalCap {
        var radius = Angle.radians(0)
        for cap in caps {
            radius = max(radius, angle(between: center, cap.center) + cap.radius)
        }
        return SphericalCap(center: center, radius: radius)
    }
}
