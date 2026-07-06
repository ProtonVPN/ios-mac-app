//
//  Created on 07.07.2026 by John Biggs.
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
import simd
import Triangulation

/// The globe's fill mesh, resolved for reading by the CPU side.
///
/// TODO(SE-0516): once `Iterable` ships and `Span` conforms, store `Span`s here instead of buffer pointers and make
/// `triangles(of:)` a lazy `Iterable` chain; today a lazy sequence cannot capture a span, and these pointers are the
/// last span-typable seam.
public struct MapGlobeMesh {
    /// Unit-sphere fill vertices (each also its surface normal).
    public let vertices: UnsafeBufferPointer<SIMD3<Float>>
    /// Triangle indices into `vertices`.
    public let indices: UnsafeBufferPointer<UInt32>

    /// `country`'s fill triangles, walked lazily off the mesh with no allocation per step. Every scan iterates this
    /// one sequence, so no two scans can walk the buffers differently. The sequence borrows the mesh's buffers and
    /// must not outlive the `withMesh` scope that produced them.
    public func triangles(of country: MapGlobeCountry) -> some Sequence<SphericalTriangle> {
        country.fillRanges.lazy.flatMap { range in
            stride(from: range.lowerBound, through: range.upperBound - 3, by: 3).lazy.map { i in
                SphericalTriangle(
                    vertices[Int(indices[i])],
                    vertices[Int(indices[i + 1])],
                    vertices[Int(indices[i + 2])]
                )
            }
        }
    }
}

public extension MapGlobeModel where Storage == InMemory {
    func withMesh<R>(_ body: (MapGlobeMesh) throws -> R) rethrows -> R {
        try fillVertices.withUnsafeBufferPointer { vertices in
            try fillIndices.withUnsafeBufferPointer { indices in
                try body(MapGlobeMesh(vertices: vertices, indices: indices))
            }
        }
    }
}

public extension MapGlobeModel where Storage == Mapped {
    /// Resolves the mesh against the blob this model was decoded from; the owner does the pairing
    /// (`WorldGlobe.withMesh` in the app).
    func withMesh<R>(in blob: UnsafeRawBufferPointer, _ body: (MapGlobeMesh) throws -> R) rethrows -> R {
        try fillVertices.withUnsafeBufferPointer(in: blob) { vertices in
            try fillIndices.withUnsafeBufferPointer(in: blob) { indices in
                try body(MapGlobeMesh(vertices: vertices, indices: indices))
            }
        }
    }
}
