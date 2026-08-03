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

import Ergonomics
import MapShaderTypes
import simd
import Triangulation

/// Render-ready representation of the world map on a unit sphere: the globe.
///
/// Produced offline by `MapBaker` and serialized to `world-globe.bin`. Every position is a point on the unit sphere
/// centered at the origin, so the position also serves as the surface normal. Country fills are real triangle meshes,
/// and back-face culling alone hides the far hemisphere, so there is no depth buffer. Borders are short segments
/// expanded into ribbons in the vertex shader.
///
/// The `Storage` generic type communicates the characteristics of the underlying memory used by the model. `InMemory`
/// models hold their arrays, while `Mapped` models are zero-copy views into the memory-mapped binary globe data.
public struct MapGlobeModel<Storage: BinaryBacking>: Sendable {
    /// Unit-sphere fill vertices (each also serves as its surface normal).
    public let fillVertices: BinaryArray<SIMD3<Float>, Storage>
    /// Triangle indices into `fillVertices`.
    public let fillIndices: BinaryArray<UInt32, Storage>

    /// Border segments on the sphere, expanded to tangent-plane ribbons in the shader.
    public let borderSegments: BinaryArray<MapGlobeSegment, Storage>
    public let borderColor: SIMD4<Float>

    /// Per-path draw list in document order, which is the order the renderer draws in.
    public let drawOrder: [MapGlobeDrawUnit]
    /// Per-country geometry keyed by SVG node id (a country code, or an "x"-suffixed mainland variant), for
    /// highlighting and for rotating the globe to face a country.
    public let countries: [String: MapGlobeCountry]

    public init(
        fillVertices: BinaryArray<SIMD3<Float>, Storage>,
        fillIndices: BinaryArray<UInt32, Storage>,
        borderSegments: BinaryArray<MapGlobeSegment, Storage>,
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

public extension MapGlobeModel {
    /// The empty globe: no geometry, no countries. What a consumer degrades to when the baked resource can't be loaded
    /// — the renderer then draws only the ocean sphere. `BinaryArray()` is the storage-neutral empty, so this is valid
    /// under any `Storage`.
    static var empty: Self {
        Self(
            fillVertices: BinaryArray(),
            fillIndices: BinaryArray(),
            borderSegments: BinaryArray(),
            borderColor: .zero,
            drawOrder: [],
            countries: [:]
        )
    }
}

public extension MapGlobeModel where Storage == InMemory {
    /// InMemory-storage convenience for the baker and synthetic test models.
    init(
        fillVertices: [SIMD3<Float>],
        fillIndices: [UInt32],
        borderSegments: [MapGlobeSegment],
        borderColor: SIMD4<Float>,
        drawOrder: [MapGlobeDrawUnit],
        countries: [String: MapGlobeCountry]
    ) {
        self.init(
            fillVertices: BinaryArray(fillVertices),
            fillIndices: BinaryArray(fillIndices),
            borderSegments: BinaryArray(borderSegments),
            borderColor: borderColor,
            drawOrder: drawOrder,
            countries: countries
        )
    }
}

/// One border segment: two unit-sphere endpoints. The shader expands it into a ribbon in the local tangent plane. The
/// layout lives once in `MapShaderTypes.h`, shared verbatim with the GPU side, so the buffer the codec bulk-loads is
/// the buffer the border pass consumes. Re-exported here so MapModel's Metal-free consumers, the baker and the codec,
/// never touch the shader-types module directly.
public typealias MapGlobeSegment = MapShaderTypes.MapGlobeSegment

// The C struct can't synthesize Equatable; provided here (its Swift-facing owner) so tests can assert on whole values
// (`expectNoDifference`) instead of decomposing field by field.
extension MapGlobeSegment: Equatable {
    public static func == (lhs: Self, rhs: Self) -> Bool {
        lhs.a == rhs.a && lhs.b == rhs.b
    }
}

/// One path's geometry, drawn fill-then-border in document order.
public struct MapGlobeDrawUnit: Equatable, Sendable {
    public let color: SIMD4<Float>
    public let fillRange: Range<Int> // into MapGlobeModel.fillIndices
    public let borderRange: Range<Int> // into MapGlobeModel.borderSegments
    public let borderHalfWidth: Float // sphere-space half-width for this path's border
    /// Unit direction to the path's centroid, for whole-path back-face culling.
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

/// Per-country lookup for highlighting and for rotating the globe to face the country.
public struct MapGlobeCountry: Equatable, Sendable {
    /// Bounding cap on the sphere: its center is the direction to rotate toward so the country faces the
    /// camera, and its radius is the half-angle the camera zooms to fit. Baked alongside the geometry.
    public let cap: SphericalCap
    /// Unit direction the disconnected "you are here" pin renders at.
    public let pin: SIMD3<Float>
    public let fillRanges: [Range<Int>]
    public let borderRanges: [Range<Int>]

    public init(
        cap: SphericalCap,
        pin: SIMD3<Float>,
        fillRanges: [Range<Int>],
        borderRanges: [Range<Int>]
    ) {
        self.cap = cap
        self.pin = pin
        self.fillRanges = fillRanges
        self.borderRanges = borderRanges
    }
}
