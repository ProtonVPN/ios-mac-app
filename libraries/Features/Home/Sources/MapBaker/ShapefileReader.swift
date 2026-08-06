//
//  Created on 05/08/2026.
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
import Foundation
import simd

/// Reads the vertex paths out of an ESRI shapefile, just enough of the format for the bundled Natural Earth
/// reference data (polygons and polylines, WGS84 coordinates as longitude and latitude in degrees). The attribute
/// and index side files are not needed: the calibration only wants the vertices.
///
/// The file is walked with `BinaryDecoder`, so the reader is a sequence of named field reads rather than
/// arithmetic on byte offsets, and every read is bounds-checked: a truncated or corrupt file throws instead of
/// reading past its end. The only literal numbers are the format's own, named in `Format`.
enum ShapefileReader {
    enum ReadError: Error, Equatable {
        case notAShapefile
        case unsupportedShapeType(Int32)
        /// A record disagrees with itself: fields running past the length its own header declared, or part
        /// indices that do not walk forward through the points that follow them.
        case malformedRecord
    }

    /// One file's parts, and whether they are rings.
    struct VertexPaths {
        let paths: [[SIMD2<Double>]]
        /// True for a polygon file, whose paths are rings repeating their first vertex at the end.
        let closed: Bool
    }

    /// The format's own numbers, which are the only ones this reader needs to know.
    private enum Format {
        /// The file code every shapefile opens with. Big-endian, and the format's signature.
        static let fileCode: Int32 = 9994
        /// The two shape types the reference data uses. A file holds one type throughout, apart from the null
        /// placeholders left where a feature was deleted.
        static let polyline: Int32 = 3
        static let polygon: Int32 = 5
        /// Record content lengths are counted in 16-bit words.
        static let bytesPerLengthWord = 2
    }

    /// Every part of every record, as (longitude, latitude) pairs in degrees. Polygon and polyline records have
    /// the same byte layout, so `decodeParts` reads both.
    static func vertexPaths(from data: Data) throws -> VertexPaths {
        try BinaryDecoder<InMemory>.decode(data) { coder in
            let shapeType = try decodeHeader(&coder)
            guard shapeType == Format.polygon || shapeType == Format.polyline else {
                throw ReadError.unsupportedShapeType(shapeType)
            }
            return try VertexPaths(
                paths: decodeRecords(&coder, of: shapeType),
                closed: shapeType == Format.polygon
            )
        }
    }

    /// Reads the fixed header and returns the shape type the file holds. The header mixes endianness: the file
    /// code and the lengths are big-endian, everything from the version on is little-endian.
    private static func decodeHeader(_ coder: inout BinaryDecoder<InMemory>) throws -> Int32 {
        guard try coder.bigEndianInt32() == Format.fileCode else { throw ReadError.notAShapefile }
        // Five unused fields, always zero.
        for _ in 0 ..< 5 {
            _ = try coder.bigEndianInt32()
        }
        _ = try coder.bigEndianInt32() // total file length, which the record walk below does not need
        _ = try coder.littleEndianInt32() // format version
        let shapeType = try coder.littleEndianInt32()
        try coder.skip(MemoryLayout<Double>.stride * 8) // the file's bounding box, then its Z and M ranges
        return shapeType
    }

    /// Walks the records to the end of the file, collecting the parts of every record of the file's own shape
    /// type. Each record declares its content length, so the walk can step over a null placeholder or the
    /// measure arrays a Z or M variant appends without knowing their layouts.
    private static func decodeRecords(
        _ coder: inout BinaryDecoder<InMemory>,
        of shapeType: Int32
    ) throws -> [[SIMD2<Double>]] {
        var paths: [[SIMD2<Double>]] = []
        while !coder.isAtEnd {
            _ = try coder.bigEndianInt32() // record number, 1-based and sequential
            let contentByteCount = try Int(coder.bigEndianInt32()) * Format.bytesPerLengthWord
            let remainingAtStart = coder.remainingByteCount

            if try coder.littleEndianInt32() == shapeType {
                try paths.append(contentsOf: decodeParts(&coder))
            }

            let consumed = remainingAtStart - coder.remainingByteCount
            guard consumed <= contentByteCount else { throw ReadError.malformedRecord }
            try coder.skip(contentByteCount - consumed)
        }
        return paths
    }

    /// Reads one polygon or polyline record's parts, positioned just after its shape type.
    private static func decodeParts(_ coder: inout BinaryDecoder<InMemory>) throws -> [[SIMD2<Double>]] {
        try coder.skip(MemoryLayout<Double>.stride * 4) // the record's own bounding box
        let partCount = try Int(coder.littleEndianInt32())
        let pointCount = try Int(coder.littleEndianInt32())
        // Both counts size arrays below. Validating them here keeps a corrupt file from forcing a huge or
        // negative allocation.
        guard partCount >= 0, pointCount >= 0,
              partCount * MemoryLayout<Int32>.stride
              + pointCount * MemoryLayout<SIMD2<Double>>.stride <= coder.remainingByteCount
        else { throw ReadError.malformedRecord }

        // Each part is the index of its first point, and the last part runs to the end of the record's points.
        var starts: [Int] = []
        starts.reserveCapacity(partCount + 1)
        for _ in 0 ..< partCount {
            try starts.append(Int(coder.littleEndianInt32()))
        }
        starts.append(pointCount)
        guard starts.first ?? 0 >= 0, zip(starts, starts.dropFirst()).allSatisfy(<=) else {
            throw ReadError.malformedRecord
        }

        // A point is a pair of little-endian doubles, which is this host's own layout for a `SIMD2<Double>`.
        var points: [SIMD2<Double>] = []
        points.reserveCapacity(pointCount)
        for _ in 0 ..< pointCount {
            try points.append(coder.read())
        }

        return (0 ..< partCount).map { Array(points[starts[$0] ..< starts[$0 + 1]]) }
    }
}

/// Named endian reads, so every field above states the byte order the shapefile stores it in.
private extension BinaryDecoder<InMemory> {
    mutating func bigEndianInt32() throws -> Int32 {
        try Int32(bigEndian: read())
    }

    mutating func littleEndianInt32() throws -> Int32 {
        try Int32(littleEndian: read())
    }
}
