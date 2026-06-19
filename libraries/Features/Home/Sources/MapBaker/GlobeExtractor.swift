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
import Foundation
import MapModel
import simd
import SVGView

/// Converts the parsed SVG into a 3-D `MapGlobeModel` on the unit sphere.
///
/// Pipeline per path: densify long segments (so they hug the sphere), triangulate each polygon (GEOS
/// constrained Delaunay under the even-odd fill rule — see `GeosTriangulator`), un-project every vertex
/// from Natural-Earth map space to a unit-sphere position, and emit border segments. Country
/// centroids/caps are accumulated for the rotate-to-country animation. Triangle count is bounded because
/// the source polylines are already dense — densification only splits the rare long straight border.
enum GlobeExtractor {
    /// Sphere-arc tolerance (radians) for densifying long segments. ~1°. Most source segments are far
    /// shorter and pass through untouched.
    private static let densifyTolerance: Float = 1.0 * .pi / 180
    /// Triangulated-vs-polygon area ratio above which a ring is counted as imperfect (logged as a
    /// negligible sliver), and the higher ratio above which it's flagged as a gross failure.
    private static let imperfectAreaRatio: Float = 0.02
    private static let grossAreaRatio: Float = 0.15

    static func extract(from root: SVGNode) -> MapGlobeModel {
        let bounds = root.bounds()
        let proj = Unprojector(bounds: bounds)
        let paths = MapExtractor.collectPaths(from: root)
        // map-space stroke half-width → sphere units (equatorial circumference 2π over the map width)
        let halfWidthScale = Float(2 * Double.pi / Double(bounds.width))

        var fillVertices: [SIMD3<Float>] = []
        var fillIndices: [UInt32] = []
        var borderSegments: [MapGlobeSegment] = []
        var borderColor = SIMD4<Float>(0, 0, 0, 0)
        var drawOrder: [MapGlobeDrawUnit] = []
        var badRings = 0 // rings whose triangulated area ≠ polygon area (a triangulation failure)
        var totalPolyArea: Float = 0
        var failInfo: [(area: Float, ratio: Float, n: Int, ids: [String])] = []

        struct PathOut {
            let ids: [String]
            let fill: Range<Int>
            let border: Range<Int>
            let centroid: SIMD3<Float>
            let radius: Float
            let bounds: CGRect
        }
        var pathOuts: [PathOut] = []

        for path in paths {
            let denseRings = path.rings.map { densify($0, proj: proj) }

            // Fills: triangulate the whole path at once under the even-odd rule (the source's
            // `fill-rule: evenodd`), so interior lakes (Lake Winnipeg, the Great Bear/Slave lakes) carve
            // as holes and islands stay filled. GEOS repairs the source's near-duplicate
            // self-intersections and triangulates the interior exactly — concave coastline inlets (the
            // Great Lakes) carve cleanly too, with no bridge artifacts.
            let fillStart = fillIndices.count
            let vertStart = fillVertices.count
            if path.fillColor != nil {
                let (verts2D, tris, polyArea) = GeosTriangulator.triangulate(rings: denseRings.map(\.points))
                if !tris.isEmpty {
                    let stats = Self.areaStats(polyArea: Float(polyArea), verts: verts2D, tris: tris)
                    totalPolyArea += stats.poly
                    if stats.poly > 0, stats.ratio > Self.imperfectAreaRatio {
                        badRings += 1
                        failInfo.append((stats.poly, stats.ratio, verts2D.count, path.ancestorIDs))
                    }
                    let base = UInt32(fillVertices.count)
                    for v in verts2D {
                        fillVertices.append(proj.sphere(v))
                    }
                    // Emit each triangle with outward (CCW-from-outside) winding so back-face culling hides
                    // the far hemisphere — independent of the sphere's coordinate handedness.
                    for t in tris {
                        let i0 = base + UInt32(t.0), i1 = base + UInt32(t.1), i2 = base + UInt32(t.2)
                        let v0 = fillVertices[Int(i0)], v1 = fillVertices[Int(i1)], v2 = fillVertices[Int(i2)]
                        if simd_dot(simd_cross(v1 - v0, v2 - v0), v0) >= 0 {
                            fillIndices.append(contentsOf: [i0, i1, i2])
                        } else {
                            fillIndices.append(contentsOf: [i0, i2, i1])
                        }
                    }
                }
            }
            let fillRange = fillStart ..< fillIndices.count

            // Borders ---------------------------------------------------------------------------------
            let borderStart = borderSegments.count
            if let stroke = path.strokeColor, path.strokeHalfWidth > 0 {
                borderColor = stroke
                for ring in denseRings {
                    let pts = ring.points
                    guard pts.count >= 2 else { continue }
                    let count = ring.closed ? pts.count : pts.count - 1
                    for i in 0 ..< count {
                        let a = proj.sphere(pts[i])
                        let b = proj.sphere(pts[(i + 1) % pts.count])
                        if simd_distance_squared(a, b) < 1e-12 { continue }
                        borderSegments.append(MapGlobeSegment(a: a, b: b))
                    }
                }
            }
            let borderRange = borderStart ..< borderSegments.count

            guard !fillRange.isEmpty || !borderRange.isEmpty else { continue }

            // Centre = the country's 2-D bounding-box centre un-projected — matching the flat map's
            // centring exactly, and avoiding the poleward bias of averaging unit vectors over a country
            // that spans a wide longitude. Radius is the max sphere-angle to the path's vertices.
            let sphereVerts: [SIMD3<Float>] = vertStart < fillVertices.count
                ? Array(fillVertices[vertStart ..< fillVertices.count])
                : borderSegments[borderStart ..< borderSegments.count].map(\.a)
            let centroid = proj.sphere(SIMD2<Float>(Float(path.pointBounds.midX), Float(path.pointBounds.midY)))
            let radius = maxAngle(centroid, sphereVerts)

            drawOrder.append(MapGlobeDrawUnit(
                color: path.fillColor ?? SIMD4<Float>(0, 0, 0, 0),
                fillRange: fillRange,
                borderRange: borderRange,
                borderHalfWidth: path.strokeHalfWidth * halfWidthScale,
                centroid: centroid
            ))
            pathOuts.append(PathOut(
                ids: path.ancestorIDs,
                fill: fillRange,
                border: borderRange,
                centroid: centroid,
                radius: radius,
                bounds: path.pointBounds
            ))
        }

        if badRings > 0 {
            let failArea = failInfo.reduce(Float(0)) { $0 + $1.area }
            let pct = totalPolyArea > 0 ? failArea / totalPolyArea * 100 : 0
            let gross = failInfo.filter { $0.ratio > Self.grossAreaRatio }
            print(String(format: "MapBaker: %d rings triangulate imperfectly (%.3f%% of land — negligible slivers on tiny islands)", badRings, pct))
            if !gross.isEmpty {
                print("MapBaker: WARNING — \(gross.count) rings have a gross (>15%) area mismatch:")
                for f in gross.sorted(by: { $0.area > $1.area }).prefix(10) {
                    print(String(format: "    area=%.0f ratio=%.2f n=%d ids=%@", f.area, f.ratio, f.n, f.ids.joined(separator: ",")))
                }
            }
        }
        return MapGlobeModel(
            fillVertices: fillVertices,
            fillIndices: fillIndices,
            borderSegments: borderSegments,
            borderColor: borderColor,
            drawOrder: drawOrder,
            countries: countries(proj: proj, from: pathOuts.map { ($0.ids, $0.fill, $0.border, $0.centroid, $0.radius, $0.bounds) })
        )
    }

    // MARK: - Countries

    private static func countries(
        proj: Unprojector,
        from outs: [(ids: [String], fill: Range<Int>, border: Range<Int>, centroid: SIMD3<Float>, radius: Float, bounds: CGRect)]
    ) -> [String: MapGlobeCountry] {
        var byID: [String: [Int]] = [:]
        for (i, out) in outs.enumerated() {
            for id in out.ids {
                byID[id, default: []].append(i)
            }
        }
        var result: [String: MapGlobeCountry] = [:]
        for (id, members) in byID {
            // Country centre = union 2-D bounding-box centre un-projected (matches the flat map's
            // centring). Radius encloses every member cap. NB: for a country with members that wrap the
            // antimeridian (e.g. the Aleutians) the union box spans most of the map and this centre is
            // wrong — but the camera rotates to the `…x` *mainland* variant, which doesn't wrap, so the
            // affected aggregate centre is never used for framing.
            var bbox = outs[members[0]].bounds
            for m in members.dropFirst() {
                bbox = bbox.union(outs[m].bounds)
            }
            let centroid = proj.sphere(SIMD2<Float>(Float(bbox.midX), Float(bbox.midY)))
            var radius: Float = 0
            for m in members {
                let angle = acos(max(-1, min(1, simd_dot(centroid, outs[m].centroid))))
                radius = max(radius, angle + outs[m].radius)
            }
            result[id] = MapGlobeCountry(
                centroid: centroid,
                angularRadius: radius,
                fillRanges: mergeRanges(members.map { outs[$0].fill }.filter { !$0.isEmpty }),
                borderRanges: mergeRanges(members.map { outs[$0].border }.filter { !$0.isEmpty })
            )
        }
        return result
    }

    /// Largest sphere-angle (radians) from `center` to any vertex — the bounding-cap half-angle.
    private static func maxAngle(_ center: SIMD3<Float>, _ verts: [SIMD3<Float>]) -> Float {
        var radius: Float = 0
        for v in verts {
            radius = max(radius, acos(max(-1, min(1, simd_dot(center, v)))))
        }
        return radius
    }

    private static func mergeRanges(_ ranges: [Range<Int>]) -> [Range<Int>] {
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

    // MARK: - Densification

    private static func densify(_ ring: MapExtractor.Ring, proj: Unprojector) -> MapExtractor.Ring {
        let pts = ring.points
        guard pts.count >= 2 else { return ring }
        var out: [SIMD2<Float>] = []
        let count = ring.closed ? pts.count : pts.count - 1
        for i in 0 ..< count {
            let a = pts[i]
            let b = pts[(i + 1) % pts.count]
            out.append(a)
            let arc = proj.arc(a, b)
            if arc > densifyTolerance {
                let pieces = Int((arc / densifyTolerance).rounded(.up))
                for k in 1 ..< pieces {
                    out.append(a + (b - a) * (Float(k) / Float(pieces)))
                }
            }
        }
        if !ring.closed { out.append(pts[pts.count - 1]) }
        return MapExtractor.Ring(points: out, closed: ring.closed)
    }

    // MARK: - Validation

    /// GEOS-computed filled area (outer minus holes) vs triangulated area; a large ratio means the
    /// triangulation dropped or overlapped triangles. 2-D check, before un-projection.
    private static func areaStats(polyArea: Float, verts: [SIMD2<Float>], tris: [(Int, Int, Int)]) -> (poly: Float, ratio: Float) {
        var triArea: Float = 0
        for t in tris {
            let a = verts[t.0], b = verts[t.1], c = verts[t.2]
            triArea += abs((b.x - a.x) * (c.y - a.y) - (c.x - a.x) * (b.y - a.y)) / 2
        }
        guard polyArea > 0 else { return (0, 0) }
        return (polyArea, abs(triArea - polyArea) / polyArea)
    }
}

// MARK: - Natural Earth inversion + sphere mapping

/// Inverts the Natural Earth projection (recovering lat/long from baked map coords) and maps to the unit
/// sphere. Constants mirror `Ergonomics/NaturalEarthProjection`; verified to round-trip to ~1e-13°.
struct Unprojector {
    /// Half-extents of the Natural Earth projection at the map's reference scale: x spans
    /// ±`projectionHalfWidth`, y spans ±`projectionHalfHeight`. Mirror `Ergonomics/NaturalEarthProjection`.
    private static let projectionHalfWidth = 2.73539
    private static let projectionHalfHeight = 1.42239
    /// Bisection steps inverting the (monotonic) latitude polynomial. Each step halves the ±90° interval,
    /// so ~50 exhausts `Double`'s ~52-bit mantissa — past that the result no longer changes.
    private static let latitudeBisectionSteps = 50

    private let ratioX: Double
    private let ratioY: Double
    private let midX: Double
    private let midY: Double

    init(bounds: CGRect) {
        self.ratioX = Double(bounds.width) / (2 * Self.projectionHalfWidth)
        self.ratioY = Double(bounds.height) / (2 * Self.projectionHalfHeight)
        self.midX = Double(bounds.width) / 2
        self.midY = Double(bounds.height) / 2
    }

    func sphere(_ p: SIMD2<Float>) -> SIMD3<Float> {
        let (lat, lon) = latLon(p)
        // Shared with the app's pin placement so the two never drift; winding is re-enforced outward on
        // the triangles afterwards.
        return GlobeGeometry.unitSphere(latitudeDegrees: Float(lat), longitudeDegrees: Float(lon))
    }

    /// Sphere arc length (radians) between two map points — used to decide segment densification.
    func arc(_ p0: SIMD2<Float>, _ p1: SIMD2<Float>) -> Float {
        let a = sphere(p0)
        let b = sphere(p1)
        return acos(max(-1, min(1, simd_dot(a, b))))
    }

    private func latLon(_ p: SIMD2<Float>) -> (lat: Double, lon: Double) {
        let projX = (Double(p.x) - midX) / ratioX
        let projY = (midY - Double(p.y)) / ratioY
        // latitude: dPolynomial is monotonic → bisection
        var lo = -Double.pi / 2
        var hi = Double.pi / 2
        for _ in 0 ..< Self.latitudeBisectionSteps {
            let mid = (lo + hi) / 2
            if dPolynomial(mid) < projY { lo = mid } else { hi = mid }
        }
        let latR = (lo + hi) / 2
        let l = lPolynomial(latR)
        let lonR = abs(l) > 1e-12 ? projX / l : 0
        var lon = lonR * 180 / .pi + 10 // reverse the map's −10° shift
        if lon > 180 { lon -= 360 }
        if lon < -180 { lon += 360 }
        return (latR * 180 / .pi, lon)
    }

    private func lPolynomial(_ lat: Double) -> Double {
        0.870700 - 0.131979 * pow(lat, 2) - 0.013791 * pow(lat, 4) + 0.003971 * pow(lat, 10) - 0.001529 * pow(lat, 12)
    }

    private func dPolynomial(_ lat: Double) -> Double {
        let s = 1.007226 + 0.015085 * pow(lat, 2) - 0.044475 * pow(lat, 6) + 0.028874 * pow(lat, 8) - 0.005916 * pow(lat, 10)
        return s * lat
    }
}
