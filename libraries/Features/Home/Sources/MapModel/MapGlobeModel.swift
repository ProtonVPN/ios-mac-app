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

/// Render-ready representation of the world map on a **unit sphere** (the globe).
///
/// Produced offline by `MapBaker` and serialised to `world-globe.bin`. Every position is a point on the
/// unit sphere centred at the origin, so the position also *is* the surface normal — which is what keeps
/// a future day/night terminator a pure shader addition (no geometry change). Country fills are real
/// triangle meshes (back-face culling alone hides the far hemisphere — there is no depth buffer);
/// borders are short great-circle-ish segments expanded into ribbons in the vertex shader, as on the
/// flat map.
public struct MapGlobeModel: Sendable {
    /// Unit-sphere fill vertices (each also serves as its surface normal).
    public let fillVertices: [SIMD3<Float>]
    /// Triangle indices into `fillVertices`.
    public let fillIndices: [UInt32]

    /// Border segments on the sphere, expanded to tangent-plane ribbons in the shader.
    public let borderSegments: [MapGlobeSegment]
    public let borderColor: SIMD4<Float>

    /// Per-path draw list in document order (painter order for the front hemisphere — see `GlobeRenderer`).
    public let drawOrder: [MapGlobeDrawUnit]
    /// Per-country geometry keyed by SVG node id (country code + `…x` mainland variants), for highlight
    /// and for rotating the globe to face a country.
    public let countries: [String: MapGlobeCountry]

    public init(
        fillVertices: [SIMD3<Float>],
        fillIndices: [UInt32],
        borderSegments: [MapGlobeSegment],
        borderColor: SIMD4<Float>,
        drawOrder: [MapGlobeDrawUnit],
        countries: [String: MapGlobeCountry]
    ) {
        self.fillVertices = fillVertices
        self.fillIndices = fillIndices
        self.borderSegments = borderSegments
        self.borderColor = borderColor
        self.drawOrder = drawOrder
        self.countries = countries
    }
}

/// One border segment: two unit-sphere endpoints. The shader expands it into a ribbon in the local
/// tangent plane (offset perpendicular via `cross(normal, dir)` where the normal is the endpoint itself).
public struct MapGlobeSegment: Sendable {
    public var a: SIMD3<Float>
    public var b: SIMD3<Float>

    public init(a: SIMD3<Float>, b: SIMD3<Float>) {
        self.a = a
        self.b = b
    }
}

/// One path's geometry, drawn fill-then-border in document order.
public struct MapGlobeDrawUnit: Sendable {
    public let color: SIMD4<Float>
    public let fillRange: Range<Int> // into MapGlobeModel.fillIndices
    public let borderRange: Range<Int> // into MapGlobeModel.borderSegments
    public let borderHalfWidth: Float // sphere-space half-width for this path's border
    /// Unit-direction to the path's centroid — for whole-unit back-face culling.
    public let centroid: SIMD3<Float>

    public init(
        color: SIMD4<Float>,
        fillRange: Range<Int>,
        borderRange: Range<Int>,
        borderHalfWidth: Float,
        centroid: SIMD3<Float>
    ) {
        self.color = color
        self.fillRange = fillRange
        self.borderRange = borderRange
        self.borderHalfWidth = borderHalfWidth
        self.centroid = centroid
    }
}

/// Per-country lookup for highlight + "rotate to face this country".
public struct MapGlobeCountry: Sendable {
    /// Unit-direction to rotate toward so the country faces the camera.
    public let centroid: SIMD3<Float>
    /// Bounding-cap half-angle (radians) around `centroid`, for zoom-to-fit.
    public let angularRadius: Float
    public let fillRanges: [Range<Int>]
    public let borderRanges: [Range<Int>]

    public init(
        centroid: SIMD3<Float>,
        angularRadius: Float,
        fillRanges: [Range<Int>],
        borderRanges: [Range<Int>]
    ) {
        self.centroid = centroid
        self.angularRadius = angularRadius
        self.fillRanges = fillRanges
        self.borderRanges = borderRanges
    }
}
