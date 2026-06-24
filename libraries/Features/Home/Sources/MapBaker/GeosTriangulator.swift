//
//  Created on 19/06/2026.
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

import simd

/// Polygon triangulator backed by GEOS, the engine behind PostGIS and QGIS. The source country outlines
/// are slightly non-simple, with near-duplicate spike clusters that make a plain ear-clipper emit bridge
/// triangles across concave inlets and past borders. GEOS `MakeValid` repairs those self-intersections,
/// then a constrained Delaunay triangulation fills the polygon interior, keeping every input vertex
/// (including the densified boundary midpoints) as a constraint edge so the fill outline hugs the sphere
/// instead of collapsing long borders into chords.
///
/// Baker-only: GEOS is not reachable from the `Home` product, so it never ships in the app.
enum GeosTriangulator {
    private enum Constants {
        /// Weld-grid cells per map unit when deduplicating triangle corners. GEOS reproduces input
        /// vertices exactly, so coincident corners round into the same cell and share an index.
        static let weldCellsPerUnit: Double = 1e4
    }

    /// Triangulates the region a path's `rings` enclose under the even-odd fill rule the source SVG uses:
    /// the outer boundary, minus interior lakes, plus islands, plus any island in a lake. Symmetric
    /// difference handles the nesting and winding automatically, so no hierarchy detection is needed.
    /// Returns deduplicated vertices, index triples, and the true filled area for the baker's self-check.
    static func triangulate(rings: [[SIMD2<Float>]]) -> (verts: [SIMD2<Float>], tris: [(Int, Int, Int)], area: Double) {
        let usable = rings.filter { $0.count >= 3 }
        guard !usable.isEmpty, let geos = Geos() else { return ([], [], 0) }

        // Even-odd combine: XOR the rings together so lakes carve and islands stay, independent of ring
        // order or winding. Single-ring paths, most of the map, just pass straight through.
        var region: Geos.Geometry?
        for ring in usable {
            guard let polygon = geos.validPolygon(ring: ring) else {
                warn("rejected a ring", geos)
                continue
            }
            if let combined = region {
                region = combined.symmetricDifference(polygon)
                if region == nil { warn("symmetric difference failed", geos) }
            } else {
                region = polygon
            }
        }
        guard let region else { return ([], [], 0) }

        let area = region.area
        guard let mesh = region.constrainedDelaunayTriangulation() else {
            warn("triangulation failed", geos)
            return ([], [], area)
        }

        // GEOS emits exact copies of input vertices (constrained Delaunay adds no points of its own), so
        // shared triangle corners match exactly. Weld them so the mesh stays compact and index-shared.
        var welder = VertexWelder(cellsPerUnit: Constants.weldCellsPerUnit)
        var tris: [(Int, Int, Int)] = []
        for triangle in mesh.subgeometries {
            let ring = triangle.exteriorRingPoints
            guard ring.count >= 3 else { continue }
            let (a, b, c) = (welder.index(of: ring[0]), welder.index(of: ring[1]), welder.index(of: ring[2]))
            // The weld can collapse two GEOS vertices closer than a grid cell onto one index. Drop the
            // resulting zero-area triangle: it renders nothing, and it would land in the mesh as exactly
            // the kind of degenerate triangle the runtime containment test has to defend against.
            guard a != b, b != c, a != c else { continue }
            tris.append((a, b, c))
        }
        return (welder.vertices, tris, area)
    }

    /// Prints GEOS's own explanation for a failure, when it reported one.
    private static func warn(_ what: String, _ geos: Geos) {
        guard let message = geos.takeLastError() else { return }
        print("MapBaker: GEOS \(what): \(message)")
    }
}

/// Collapses coincident corners onto shared indices by rounding them onto a quantisation grid.
private struct VertexWelder {
    private struct GridKey: Hashable {
        let x, y: Int64
    }

    private let cellsPerUnit: Double
    private var lookup: [GridKey: Int] = [:]
    private(set) var vertices: [SIMD2<Float>] = []

    init(cellsPerUnit: Double) {
        self.cellsPerUnit = cellsPerUnit
    }

    /// The shared index for `point`, minting one the first time its grid cell is seen.
    mutating func index(of point: SIMD2<Double>) -> Int {
        let key = GridKey(x: Int64((point.x * cellsPerUnit).rounded()), y: Int64((point.y * cellsPerUnit).rounded()))
        if let existing = lookup[key] { return existing }
        let index = vertices.count
        vertices.append(SIMD2<Float>(Float(point.x), Float(point.y)))
        lookup[key] = index
        return index
    }
}
