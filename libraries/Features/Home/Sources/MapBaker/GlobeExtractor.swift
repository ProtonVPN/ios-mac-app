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
import CoreLocation
import Domain
import Ergonomics
import Foundation
import MapModel
import simd
import SVGView
import Triangulation

/// Converts the parsed SVG into a 3-D `MapGlobeModel` on the unit sphere.
///
/// The pipeline per path: densify long segments so they hug the sphere, triangulate each polygon, un-project every
/// vertex from map space to a unit-sphere position, and emit border segments. Country centroids and caps are
/// accumulated for the rotate-to-country animation. Triangle count stays bounded because the source polylines are
/// already dense, so densification only splits the rare long straight border.
enum GlobeExtractor {
    static func extract(from root: SVGNode) -> MapGlobeModel<InMemory> {
        var builder = GlobeBuilder(bounds: root.bounds())
        for path in MapExtractor.collectPaths(from: root) {
            builder.append(path)
        }
        return builder.finish()
    }
}

/// One extracted path's baked geometry: where its fill and border landed in the shared buffers, plus the bounding cap
/// and 2-D bounds the per-country aggregation works from.
private struct BakedPath {
    let ancestorIDs: [String]
    let fillRange: Range<Int>
    let borderRange: Range<Int>
    let cap: SphericalCap
    let bounds: CGRect
}

/// Accumulates the shared vertex, index, and segment buffers as paths are appended, then assembles the final model.
private struct GlobeBuilder {
    private enum Constants {
        /// Sphere-arc tolerance in radians (about a degree) for densifying long segments. Most source segments are far
        /// shorter and pass through untouched.
        static let densifyTolerance: Float = 1.0 * .pi / 180
        /// How far past the nearest fill vertex a snapped pin is carried inland, in radians. (About 20 km.)
        static let pinInlandNudge: Float = 0.2 * .pi / 180
        /// Map ids whose curated-table key differs from their uppercased form: the map says "uk" where ISO says "GB",
        /// and groups Svalbard under the non-ISO "xv" while the table lists it as "SJ".
        static let isoOverrides = ["uk": "GB", "xv": "SJ"]
    }

    private enum Dimensions {
        /// Squared-distance cull for zero-length border segments, in sphere units: about 1e-6 radians, or 6 metres of
        /// Earth. Only true duplicates, densification landing on an existing vertex, fall under it.
        static let degenerateSegmentLengthSquared: Float = 1e-12
    }

    private let unprojector: Unprojector
    /// Map-space stroke half-width to sphere units: the equatorial circumference over the map width.
    private let halfWidthScale: Float

    private var fillVertices: [SIMD3<Float>] = []
    private var fillIndices: [UInt32] = []
    private var borderSegments: [MapGlobeSegment] = []
    private var borderColor = SIMD4<Float>(0, 0, 0, 0)
    private var drawOrder: [MapGlobeDrawUnit] = []
    private var bakedPaths: [BakedPath] = []
    private var report = TriangulationReport()

    init(bounds: CGRect) {
        self.unprojector = Unprojector(bounds: bounds)
        self.halfWidthScale = Float(2 * Double.pi / Double(bounds.width))
    }

    /// Bakes one path: fill triangles, border segments, and the bounding cap the camera frames it with. Paths that
    /// produce no geometry are dropped.
    mutating func append(_ path: MapExtractor.ExtractedPath) {
        let denseRings = path.rings.map(densified)
        let vertexStart = fillVertices.count
        let fillRange = appendFill(of: path, rings: denseRings)
        let borderRange = appendBorders(of: path, rings: denseRings)
        guard !fillRange.isEmpty || !borderRange.isEmpty else { return }

        // The centre is the path's 2-D bounding-box center un-projected, which avoids the poleward bias of averaging
        // unit vectors over a country that spans a wide longitude. The radius is the largest sphere angle to the path's
        // vertices.
        let sphereVertices: [SIMD3<Float>] = vertexStart < fillVertices.count
            ? Array(fillVertices[vertexStart...])
            : borderSegments[borderRange].map(\.a)
        let centroid = unprojector.sphere(SIMD2<Float>(Float(path.pointBounds.midX), Float(path.pointBounds.midY)))
        let radius = maxSphereAngle(from: centroid, to: sphereVertices)

        drawOrder.append(MapGlobeDrawUnit(
            color: path.fillColor ?? SIMD4<Float>(0, 0, 0, 0),
            fillRange: fillRange,
            borderRange: borderRange,
            borderHalfWidth: path.strokeHalfWidth * halfWidthScale,
            centroid: centroid
        ))
        bakedPaths.append(BakedPath(
            ancestorIDs: path.ancestorIDs,
            fillRange: fillRange,
            borderRange: borderRange,
            cap: SphericalCap(center: centroid, radius: .radians(Double(radius))),
            bounds: path.pointBounds
        ))
    }

    mutating func finish() -> MapGlobeModel<InMemory> {
        report.printSummary()
        return MapGlobeModel(
            fillVertices: fillVertices,
            fillIndices: fillIndices,
            borderSegments: borderSegments,
            borderColor: borderColor,
            drawOrder: drawOrder,
            countries: countries()
        )
    }

    // MARK: - Fills

    /// Triangulates the path's fill under the even-odd rule the source SVG uses, so interior lakes carve as holes and
    /// islands stay filled, then appends the sphere vertices and triangles to the shared buffers. GEOS repairs the
    /// source's near-duplicate self-intersections and triangulates the interior exactly, so concave coastline inlets
    /// carve cleanly with no bridging triangles across them. Returns the path's slice of `fillIndices`.
    private mutating func appendFill(of path: MapExtractor.ExtractedPath, rings: [MapExtractor.Ring]) -> Range<Int> {
        let start = fillIndices.count
        guard path.fillColor != nil else { return start ..< start }

        let (vertices2D, triangles, polygonArea) = GeosTriangulator.triangulate(rings: rings.map(\.points))
        report.record(polygonArea: polygonArea, vertices: vertices2D, triangles: triangles, ids: path.ancestorIDs)
        guard !triangles.isEmpty else { return start ..< start }

        let base = UInt32(fillVertices.count)
        let sphereVertices = vertices2D.map(unprojector.sphere)
        fillVertices.append(contentsOf: sphereVertices)
        // Emit each triangle wound counter-clockwise seen from outside, so back-face culling hides the far hemisphere
        // regardless of the sphere's coordinate handedness.
        for triangle in triangles {
            let (i0, i1, i2) = (base + UInt32(triangle.0), base + UInt32(triangle.1), base + UInt32(triangle.2))
            if isOutwardFacing(sphereVertices[triangle.0], sphereVertices[triangle.1], sphereVertices[triangle.2]) {
                fillIndices.append(contentsOf: [i0, i1, i2])
            } else {
                fillIndices.append(contentsOf: [i0, i2, i1])
            }
        }
        return start ..< fillIndices.count
    }

    // MARK: - Borders

    /// Appends one segment per densified ring edge, skipping zero-length duplicates. Returns the path's slice of
    /// `borderSegments`.
    private mutating func appendBorders(of path: MapExtractor.ExtractedPath, rings: [MapExtractor.Ring]) -> Range<Int> {
        let start = borderSegments.count
        guard let stroke = path.strokeColor, path.strokeHalfWidth > 0 else { return start ..< start }
        borderColor = stroke
        for ring in rings {
            let points = ring.points
            guard points.count >= 2 else { continue }
            let edgeCount = ring.closed ? points.count : points.count - 1
            for i in 0 ..< edgeCount {
                let a = unprojector.sphere(points[i])
                let b = unprojector.sphere(points[(i + 1) % points.count])
                if simd_distance_squared(a, b) < Dimensions.degenerateSegmentLengthSquared { continue }
                borderSegments.append(MapGlobeSegment(a: a, b: b))
            }
        }
        return start ..< borderSegments.count
    }

    // MARK: - Densification

    /// Splits segments longer than `densifyTolerance` of sphere arc, so a long straight border follows the sphere's
    /// curvature once un-projected.
    private func densified(_ ring: MapExtractor.Ring) -> MapExtractor.Ring {
        let points = ring.points
        guard points.count >= 2 else { return ring }
        var out: [SIMD2<Float>] = []
        let edgeCount = ring.closed ? points.count : points.count - 1
        for i in 0 ..< edgeCount {
            let a = points[i]
            let b = points[(i + 1) % points.count]
            out.append(a)
            let arc = unprojector.arc(a, b)
            if arc > Constants.densifyTolerance {
                let pieces = Int((arc / Constants.densifyTolerance).rounded(.up))
                for k in 1 ..< pieces {
                    out.append(a + (b - a) * (Float(k) / Float(pieces)))
                }
            }
        }
        if !ring.closed { out.append(points[points.count - 1]) }
        return MapExtractor.Ring(points: out, closed: ring.closed)
    }

    // MARK: - Countries

    /// Groups the baked paths by their SVG ancestor ids and aggregates each group into one `MapGlobeCountry`: merged
    /// draw ranges plus a cap enclosing every member.
    private func countries() -> [String: MapGlobeCountry] {
        var memberIndicesByID: [String: [Int]] = [:]
        for (index, path) in bakedPaths.enumerated() {
            for id in path.ancestorIDs {
                memberIndicesByID[id, default: []].append(index)
            }
        }
        var result: [String: MapGlobeCountry] = [:]
        var curatedPins = 0
        var snappedCuratedPins = 0
        for (id, members) in memberIndicesByID {
            // The country centre is the union of the member bounding boxes, un-projected, and the radius encloses every
            // member cap. For a country with members that wrap the antimeridian, like the Aleutians, the union box
            // spans most of the map and this centre is wrong. The camera rotates to the mainland variant though, which
            // doesn't wrap, so the affected aggregate centre is never used for framing.
            var unionBounds = bakedPaths[members[0]].bounds
            for member in members.dropFirst() {
                unionBounds = unionBounds.union(bakedPaths[member].bounds)
            }
            let centroid = unprojector.sphere(SIMD2<Float>(Float(unionBounds.midX), Float(unionBounds.midY)))
            let fillRanges = mergeRanges(members.map { bakedPaths[$0].fillRange }.filter { !$0.isEmpty })
            let curated = curatedCenter(for: id)
            let pin = pinDirection(from: curated ?? centroid, fillRanges: fillRanges)
            if let curated {
                curatedPins += 1
                if pin != curated { snappedCuratedPins += 1 }
            }
            result[id] = MapGlobeCountry(
                cap: .enclosing(members.map { bakedPaths[$0].cap }, around: centroid),
                pin: pin,
                fillRanges: fillRanges,
                borderRanges: mergeRanges(members.map { bakedPaths[$0].borderRange }.filter { !$0.isEmpty })
            )
        }
        print("MapBaker: pins: \(curatedPins) from the curated table (\(snappedCuratedPins) of them snapped onto land)")
        return result
    }

    // MARK: - Pins

    /// The curated table's center for a map id, on the unit sphere, or nil for ids the table doesn't know (named island
    /// paths, `pathNNNN`). Mainland variants look up their base country, so "usx" pins where "us" does.
    private func curatedCenter(for id: String) -> SIMD3<Float>? {
        var id = id
        if id.count == 3, id.hasSuffix("x") { id = String(id.dropLast()) }
        let key = Constants.isoOverrides[id] ?? id.uppercased()
        return CountriesCoordinates.countryCenterCoordinates(key).map {
            GlobeGeometry.unitSphere(latitudeDegrees: Float($0.latitude), longitudeDegrees: Float($0.longitude))
        }
    }

    /// Where the disconnected pin renders. Uses `candidate` when it lands on the given fill, otherwise takes the
    /// closest fill vertex and nudges it inland.
    private func pinDirection(from candidate: SIMD3<Float>, fillRanges: [Range<Int>]) -> SIMD3<Float> {
        if lands(candidate, onAnyOf: fillRanges) { return candidate }
        var nearest = candidate
        var nearestDot: Float = -2 // cos(angle), larger is nearer. Below any real dot, so the first vertex wins.
        for range in fillRanges {
            for index in range {
                let vertex = fillVertices[Int(fillIndices[index])]
                let dot = simd_dot(candidate, vertex)
                if dot > nearestDot {
                    nearestDot = dot
                    nearest = vertex
                }
            }
        }
        guard nearestDot > -2 else { return candidate }
        return nudgedInland(from: candidate, past: nearest, fillRanges: fillRanges)
    }

    /// Whether `point` lies on any triangle of the given fill ranges.
    private func lands(_ point: SIMD3<Float>, onAnyOf fillRanges: [Range<Int>]) -> Bool {
        for range in fillRanges {
            var index = range.lowerBound
            while index + 2 < range.upperBound {
                let a = fillVertices[Int(fillIndices[index])]
                let b = fillVertices[Int(fillIndices[index + 1])]
                let c = fillVertices[Int(fillIndices[index + 2])]
                // cos of the widest side, and of double it: cos(2x) = 2cos(x)^2 - 1. Cosines compare reversed.
                let widest = min(min(simd_dot(a, b), simd_dot(b, c)), simd_dot(c, a))
                let nearEnough = simd_dot(point, a) >= 2 * widest * widest - 1
                if nearEnough, SphericalTriangle(a, b, c).contains(point) { return true }
                index += 3
            }
        }
        return false
    }

    /// Continues past the nearest vertex along the direction the candidate approached it from, which locally points
    /// straight inland. Only accept a point that actually finds land, and then take a small half-step once more before
    /// settling for the vertex itself. This is the best heuristic so far for dealing with tiny islands/slivers of land.
    private func nudgedInland(
        from direction: SIMD3<Float>,
        past nearest: SIMD3<Float>,
        fillRanges: [Range<Int>]
    ) -> SIMD3<Float> {
        let step = nearest - direction
        guard simd_length_squared(step) > 1e-12 else { return nearest } // the candidate is the vertex itself
        let inland = simd_normalize(step) // the chord approximates the tangent at these separations
        for factor in [1, 0.5] as [Float] {
            let nudged = simd_normalize(nearest + factor * Constants.pinInlandNudge * inland)
            if lands(nudged, onAnyOf: fillRanges) { return nudged }
        }
        return nearest
    }
}

/// Tracks how faithfully each path triangulated and prints one summary at the end of the bake. Keeping the numbers here
/// keeps the geometry code free of bookkeeping.
private struct TriangulationReport {
    private enum Constants {
        /// Triangulated-versus-polygon area ratio above which a ring is counted as imperfect (logged as a negligible
        /// sliver), and the higher ratio above which it's flagged as a gross failure.
        static let imperfectAreaRatio: Float = 0.02
        static let grossAreaRatio: Float = 0.15
    }

    private struct Failure {
        let area: Float
        let ratio: Float
        let vertexCount: Int
        let ids: [String]
    }

    private var failures: [Failure] = []
    private var totalArea: Float = 0

    /// Compares the area GEOS reported for the polygon (outer ring minus holes) against the summed area of the
    /// triangles it produced, and logs the path when they disagree by more than a small fraction. A large mismatch
    /// means the triangulation dropped or overlapped triangles. The check runs in 2-D map space, before un-projection.
    /// A path with real area but no triangles at all is logged as a 100 percent mismatch, so a whole country
    /// disappearing can never look smaller than a sliver.
    mutating func record(polygonArea: Double, vertices: [SIMD2<Float>], triangles: [(Int, Int, Int)], ids: [String]) {
        let area = Float(polygonArea)
        guard area > 0 else { return }
        totalArea += area
        let ratio = triangles.isEmpty ? 1 : abs(Self.triangulatedArea(vertices, triangles) - area) / area
        guard ratio > Constants.imperfectAreaRatio else { return }
        failures.append(Failure(area: area, ratio: ratio, vertexCount: vertices.count, ids: ids))
    }

    func printSummary() {
        guard !failures.isEmpty else { return }
        let failedArea = failures.reduce(Float(0)) { $0 + $1.area }
        let pct = totalArea > 0 ? failedArea / totalArea * 100 : 0
        print(String(format: "MapBaker: %d rings triangulate imperfectly (%.3f%% of land, negligible slivers on tiny islands)", failures.count, pct))
        let gross = failures.filter { $0.ratio > Constants.grossAreaRatio }
        guard !gross.isEmpty else { return }
        print("MapBaker: WARNING: \(gross.count) rings have a gross (>\(Int(Constants.grossAreaRatio * 100))%) area mismatch:")
        for failure in gross.sorted(by: { $0.area > $1.area }).prefix(10) {
            print(String(format: "    area=%.0f ratio=%.2f vertices=%d ids=%@", failure.area, failure.ratio, failure.vertexCount, failure.ids.joined(separator: ",")))
        }
    }

    private static func triangulatedArea(_ vertices: [SIMD2<Float>], _ triangles: [(Int, Int, Int)]) -> Float {
        var area: Float = 0
        for triangle in triangles {
            let a = vertices[triangle.0], b = vertices[triangle.1], c = vertices[triangle.2]
            area += abs((b.x - a.x) * (c.y - a.y) - (c.x - a.x) * (b.y - a.y)) / 2
        }
        return area
    }
}

/// Largest angle in radians between `center` and any vertex, measured across the sphere's surface: how far the path
/// spreads out from its center. Stays on plain `Float` maths, with no `Angle` wrapping, because it scans every vertex
/// of every path.
private func maxSphereAngle(from center: SIMD3<Float>, to vertices: [SIMD3<Float>]) -> Float {
    var radius: Float = 0
    for vertex in vertices {
        radius = max(radius, acos(cosAngle(between: center, vertex)))
    }
    return radius
}

/// Merges overlapping or touching ranges, so a country's draw ranges stay compact.
private func mergeRanges(_ ranges: [Range<Int>]) -> [Range<Int>] {
    let sorted = ranges.sorted { $0.lowerBound < $1.lowerBound }
    var merged: [Range<Int>] = []
    for range in sorted {
        if let last = merged.last, range.lowerBound <= last.upperBound {
            merged[merged.count - 1] = last.lowerBound ..< max(last.upperBound, range.upperBound)
        } else {
            merged.append(range)
        }
    }
    return merged
}

// MARK: - Natural Earth inversion + sphere mapping

/// Inverts the Natural Earth projection, recovering lat + long from map coordinates, and maps onto the unit sphere.
struct Unprojector {
    private let ratioX: Double
    private let ratioY: Double
    private let midX: Double
    private let midY: Double

    init(bounds: CGRect) {
        self.ratioX = Double(bounds.width) / (2 * NaturalEarth.halfWidth)
        self.ratioY = Double(bounds.height) / (2 * NaturalEarth.halfHeight)
        self.midX = Double(bounds.width) / 2
        self.midY = Double(bounds.height) / 2
    }

    func sphere(_ p: SIMD2<Float>) -> SIMD3<Float> {
        let (lat, lon) = latLon(p)
        // Placed via the app's own GlobeGeometry.unitSphere so baked vertices and runtime pins share one
        // mapping. Winding is re-enforced outward on the triangles afterwards.
        return GlobeGeometry.unitSphere(latitudeDegrees: Float(lat), longitudeDegrees: Float(lon))
    }

    /// Sphere arc length in radians between two map points. Used to decide segment densification.
    func arc(_ p0: SIMD2<Float>, _ p1: SIMD2<Float>) -> Float {
        acos(cosAngle(between: sphere(p0), sphere(p1)))
    }

    private func latLon(_ p: SIMD2<Float>) -> (lat: Double, lon: Double) {
        let projX = (Double(p.x) - midX) / ratioX
        let projY = (midY - Double(p.y)) / ratioY
        let geo = NaturalEarth.unproject(SIMD2<Double>(projX, projY))
        var lon = geo.longitude.degrees + 10 // reverse the map's 10-degree prime-meridian shift
        if lon > 180 { lon -= 360 }
        if lon < -180 { lon += 360 }
        return (geo.latitude.degrees, lon)
    }
}
