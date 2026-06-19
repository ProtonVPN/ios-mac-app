//
//  Created on 22/06/2026.
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
//

import geos
import simd

/// Polygon triangulator backed by GEOS (the engine behind PostGIS/QGIS). The source country outlines
/// are slightly non-simple — near-duplicate "spike" clusters that make a plain ear-clipper emit "bridge"
/// triangles across concave inlets (lakes) and past borders. GEOS `MakeValid` repairs those
/// self-intersections, then a *constrained* Delaunay triangulation fills the polygon interior — keeping
/// every input vertex (including the densified boundary midpoints) as a constraint edge, so the fill
/// outline hugs the sphere instead of collapsing long borders into chords.
///
/// Baker-only: GEOS is not reachable from the `Home` product, so it never ships in the app.
enum GeosTriangulator {
    /// Map units per weld-grid cell when deduplicating triangle corners: GEOS reproduces input vertices
    /// exactly, so coincident corners round to the same `1e-4`-unit cell and share an index.
    private static let weldGridScale: Double = 1e4

    /// Triangulates the region a path's `rings` enclose under the **even-odd** fill rule (the source
    /// SVG's `fill-rule: evenodd`): the outer boundary, minus interior lakes, plus islands, plus any
    /// island-in-a-lake — nesting and winding handled automatically by symmetric-difference, so no
    /// hierarchy detection is needed. Returns deduplicated vertices, index triples, and the true filled
    /// area (for the baker's self-check).
    static func triangulate(rings: [[SIMD2<Float>]]) -> (verts: [SIMD2<Float>], tris: [(Int, Int, Int)], area: Double) {
        let usable = rings.filter { $0.count >= 3 }
        guard !usable.isEmpty, let ctx = GEOS_init_r() else { return ([], [], 0) }
        defer { GEOS_finish_r(ctx) }

        // A repaired (valid) polygon from one ring — `MakeValid` resolves the source's near-duplicate
        // self-intersections so the overlay ops below don't choke. Returns an owned geometry, or nil.
        func validPolygon(_ ring: [SIMD2<Float>]) -> OpaquePointer? {
            var pts = ring
            if let first = pts.first, let last = pts.last, first != last { pts.append(first) }
            guard pts.count >= 4, let seq = GEOSCoordSeq_create_r(ctx, UInt32(pts.count), 2) else { return nil }
            for (i, p) in pts.enumerated() {
                GEOSCoordSeq_setXY_r(ctx, seq, UInt32(i), Double(p.x), Double(p.y))
            }
            // createLinearRing takes ownership of `seq`; createPolygon takes ownership of `lr`.
            guard let lr = GEOSGeom_createLinearRing_r(ctx, seq) else {
                GEOSCoordSeq_destroy_r(ctx, seq); return nil
            }
            guard let poly = GEOSGeom_createPolygon_r(ctx, lr, nil, 0) else {
                GEOSGeom_destroy_r(ctx, lr); return nil
            }
            defer { GEOSGeom_destroy_r(ctx, poly) }
            return GEOSMakeValid_r(ctx, poly)
        }

        // Even-odd combine: XOR the rings so lakes carve and islands stay, independent of ring order or
        // winding. (Single-ring paths — most of the map — just pass straight through.)
        var region: OpaquePointer?
        for ring in usable {
            guard let poly = validPolygon(ring) else { continue }
            guard let acc = region else { region = poly; continue }
            let combined = GEOSSymDifference_r(ctx, acc, poly)
            GEOSGeom_destroy_r(ctx, acc)
            GEOSGeom_destroy_r(ctx, poly)
            region = combined
        }
        guard let region else { return ([], [], 0) }
        defer { GEOSGeom_destroy_r(ctx, region) }

        var area = 0.0
        GEOSArea_r(ctx, region, &area)
        guard let mesh = GEOSConstrainedDelaunayTriangulation_r(ctx, region) else { return ([], [], area) }
        defer { GEOSGeom_destroy_r(ctx, mesh) }

        struct GridKey: Hashable { let x: Int64; let y: Int64 }
        var verts: [SIMD2<Float>] = []
        var lookup: [GridKey: Int] = [:]
        var tris: [(Int, Int, Int)] = []

        // GEOS emits exact copies of input vertices (constrained Delaunay adds no Steiner points), so
        // shared triangle corners match to the µ-unit. Collapse them so the mesh stays index-shared
        // (compact, no T-junctions).
        func vertexIndex(_ x: Double, _ y: Double) -> Int {
            let key = GridKey(x: Int64((x * weldGridScale).rounded()), y: Int64((y * weldGridScale).rounded()))
            if let i = lookup[key] { return i }
            let i = verts.count
            verts.append(SIMD2<Float>(Float(x), Float(y)))
            lookup[key] = i
            return i
        }

        let count = GEOSGetNumGeometries_r(ctx, mesh)
        for n in 0 ..< count {
            guard let tri = GEOSGetGeometryN_r(ctx, mesh, n),
                  let ext = GEOSGetExteriorRing_r(ctx, tri),
                  let cs = GEOSGeom_getCoordSeq_r(ctx, ext) else { continue }
            var corner: [Int] = []
            for k in 0 ..< 3 {
                var x = 0.0, y = 0.0
                GEOSCoordSeq_getXY_r(ctx, cs, UInt32(k), &x, &y)
                corner.append(vertexIndex(x, y))
            }
            tris.append((corner[0], corner[1], corner[2]))
        }
        return (verts, tris, area)
    }
}
