//
//  Created on 06/07/2026.
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

import geos
import simd

/// Swift face of the GEOS C API, covering just what the baker's triangulation needs. Bound by hand because the GEOSwift
/// wrapper exposes neither `MakeValid` nor constrained Delaunay triangulation.
///
/// Single-threaded, like the baker: the error callback writes straight to the instance.
final class Geos {
    let handle: GEOSContextHandle_t

    private var lastError: String?

    init?() {
        guard let handle = GEOS_init_r() else { return nil }
        self.handle = handle
        // The callback is a plain C function pointer and can't capture, so the instance rides along through the
        // user-data pointer. Passing it unretained is safe since the callback only fires during a GEOS call, and every
        // GEOS call goes through an object that keeps this instance alive.
        _ = GEOSContext_setErrorMessageHandler_r(handle, { message, userData in
            guard let message, let userData else { return }
            Unmanaged<Geos>.fromOpaque(userData).takeUnretainedValue().lastError = String(cString: message)
        }, Unmanaged.passUnretained(self).toOpaque())
    }

    deinit {
        GEOS_finish_r(handle)
    }

    /// The message from the most recent GEOS error, cleared on read so a stale message can't be attributed to a later
    /// failure. Nil when GEOS hasn't reported anything.
    func takeLastError() -> String? {
        defer { lastError = nil }
        return lastError
    }

    /// A repaired, valid polygon built from one ring, closing it if the input isn't closed, or nil when GEOS can't make
    /// one. Repairing resolves self-intersections up front so overlay operations on the result don't choke.
    func validPolygon(ring: [SIMD2<Float>]) -> Geometry? {
        var points = ring
        if let first = points.first, let last = points.last, first != last {
            points.append(first)
        }
        guard points.count >= 4, let sequence = GEOSCoordSeq_create_r(handle, UInt32(points.count), 2) else {
            return nil
        }
        for (index, point) in points.enumerated() {
            GEOSCoordSeq_setXY_r(handle, sequence, UInt32(index), Double(point.x), Double(point.y))
        }
        // Creating a ring consumes the sequence, and creating a polygon consumes the ring, but only on success. A nil
        // result leaves the input ours to destroy.
        guard let linearRing = GEOSGeom_createLinearRing_r(handle, sequence) else {
            GEOSCoordSeq_destroy_r(handle, sequence)
            return nil
        }
        guard let polygon = GEOSGeom_createPolygon_r(handle, linearRing, nil, 0) else {
            GEOSGeom_destroy_r(handle, linearRing)
            return nil
        }
        return Geometry(owning: polygon, in: self).makeValid()
    }
}

extension Geos {
    /// Simple wrapper class for the C GEOS types.
    final class Geometry {
        fileprivate let geos: Geos
        private let pointer: OpaquePointer

        fileprivate init(owning pointer: OpaquePointer, in geos: Geos) {
            self.geos = geos
            self.pointer = pointer
        }

        deinit {
            GEOSGeom_destroy_r(geos.handle, pointer)
        }

        /// A copy with self-intersections and other invalidities repaired.
        func makeValid() -> Geometry? {
            wrap(GEOSMakeValid_r(geos.handle, pointer))
        }

        /// The regions covered by exactly one of the two geometries (see the even-odd paradigm in the SVG)
        func symmetricDifference(_ other: Geometry) -> Geometry? {
            wrap(GEOSSymDifference_r(geos.handle, pointer, other.pointer))
        }

        /// Triangulates the interior, keeping every boundary vertex as a constraint edge.
        func constrainedDelaunayTriangulation() -> Geometry? {
            wrap(GEOSConstrainedDelaunayTriangulation_r(geos.handle, pointer))
        }

        var area: Double {
            var area = 0.0
            GEOSArea_r(geos.handle, pointer, &area)
            return area
        }

        /// The child geometries, like the triangles of a triangulation, as read-only views.
        var subgeometries: [Subgeometry] {
            let count = GEOSGetNumGeometries_r(geos.handle, pointer)
            guard count > 0 else { return [] }
            return (0 ..< count).compactMap { index in
                GEOSGetGeometryN_r(geos.handle, pointer, index).map { Subgeometry(parent: self, pointer: $0) }
            }
        }

        private func wrap(_ pointer: OpaquePointer?) -> Geometry? {
            pointer.map { Geometry(owning: $0, in: geos) }
        }
    }

    struct Subgeometry {
        fileprivate let parent: Geometry
        fileprivate let pointer: OpaquePointer

        /// The points of the exterior ring, closing duplicate included. Empty when there is no ring.
        var exteriorRingPoints: [SIMD2<Double>] {
            let handle = parent.geos.handle
            guard let ring = GEOSGetExteriorRing_r(handle, pointer),
                  let sequence = GEOSGeom_getCoordSeq_r(handle, ring) else { return [] }
            var size: UInt32 = 0
            guard GEOSCoordSeq_getSize_r(handle, sequence, &size) != 0 else { return [] }
            return (0 ..< size).compactMap { index in
                var x = 0.0
                var y = 0.0
                guard GEOSCoordSeq_getXY_r(handle, sequence, index, &x, &y) != 0 else { return nil }
                return SIMD2<Double>(x, y)
            }
        }
    }
}
