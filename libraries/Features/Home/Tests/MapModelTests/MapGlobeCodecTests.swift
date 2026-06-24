//
//  Created on 30/06/2026.
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
@testable import MapModel
import simd
import Testing
import Triangulation

@Suite("MapGlobeCodec")
struct MapGlobeCodecTests {
    /// A model exercising every branch of the codec: bulk data arrays, a draw list with ranges, and a
    /// country dictionary whose keys are deliberately out of order, to prove the sort on encode.
    static let sample = MapGlobeModel(
        fillVertices: [
            SIMD3<Float>(0, 0, 1),
            SIMD3<Float>(1, 0, 0),
            SIMD3<Float>(0, 1, 0),
            SIMD3<Float>(-1, 0, 0),
        ],
        fillIndices: [0, 1, 2, 0, 2, 3],
        borderSegments: [
            MapGlobeSegment(a: SIMD3<Float>(0, 0, 1), b: SIMD3<Float>(1, 0, 0)),
            MapGlobeSegment(a: SIMD3<Float>(1, 0, 0), b: SIMD3<Float>(0, 1, 0)),
        ],
        borderColor: SIMD4<Float>(0.1, 0.2, 0.3, 1),
        drawOrder: [
            MapGlobeDrawUnit(
                color: SIMD4<Float>(1, 0, 0, 1),
                fillRange: 0 ..< 3,
                borderRange: 0 ..< 1,
                borderHalfWidth: 0.004,
                centroid: SIMD3<Float>(0.577, 0.577, 0.577)
            ),
            MapGlobeDrawUnit(
                color: SIMD4<Float>(0, 1, 0, 1),
                fillRange: 3 ..< 6,
                borderRange: 1 ..< 2,
                borderHalfWidth: 0.002,
                centroid: SIMD3<Float>(-0.577, 0.577, 0.577)
            ),
        ],
        countries: [
            "fr": MapGlobeCountry(
                cap: SphericalCap(center: SIMD3<Float>(0, 0, 1), radius: .radians(0.3)),
                fillRanges: [0 ..< 3],
                borderRanges: [0 ..< 1]
            ),
            "de": MapGlobeCountry(
                cap: SphericalCap(center: SIMD3<Float>(1, 0, 0), radius: .radians(0.2)),
                fillRanges: [0 ..< 3, 3 ..< 6],
                borderRanges: []
            ),
            "frx": MapGlobeCountry(
                cap: SphericalCap(center: SIMD3<Float>(0, 1, 0), radius: .radians(0.1)),
                fillRanges: [],
                borderRanges: [1 ..< 2]
            ),
        ]
    )

    @Test("Round-trips every field")
    func roundTrip() throws {
        let decoded = try MapGlobeCodec.decode(MapGlobeCodec.encode(Self.sample))
        let original = Self.sample

        #expect(decoded.fillVertices == original.fillVertices)
        #expect(decoded.fillIndices == original.fillIndices)
        #expect(decoded.borderColor == original.borderColor)
        #expect(decoded.borderSegments.map(\.a) == original.borderSegments.map(\.a))
        #expect(decoded.borderSegments.map(\.b) == original.borderSegments.map(\.b))

        #expect(decoded.drawOrder.map(\.color) == original.drawOrder.map(\.color))
        #expect(decoded.drawOrder.map(\.fillRange) == original.drawOrder.map(\.fillRange))
        #expect(decoded.drawOrder.map(\.borderRange) == original.drawOrder.map(\.borderRange))
        #expect(decoded.drawOrder.map(\.borderHalfWidth) == original.drawOrder.map(\.borderHalfWidth))
        #expect(decoded.drawOrder.map(\.centroid) == original.drawOrder.map(\.centroid))

        #expect(decoded.countries.keys.sorted() == original.countries.keys.sorted())
        for (code, country) in original.countries {
            let other = try #require(decoded.countries[code])
            #expect(other.cap == country.cap)
            #expect(other.fillRanges == country.fillRanges)
            #expect(other.borderRanges == country.borderRanges)
        }
    }

    @Test("Decode is the exact inverse of encode (byte-stable)")
    func decodeInvertsEncode() throws {
        // If any field were dropped, reordered, or mistyped, re-encoding the decoded model would diverge.
        let data = try MapGlobeCodec.encode(Self.sample)
        let reencoded = try MapGlobeCodec.encode(MapGlobeCodec.decode(data))
        #expect(data == reencoded)
    }

    @Test("Encoding is deterministic")
    func deterministic() throws {
        #expect(try MapGlobeCodec.encode(Self.sample) == MapGlobeCodec.encode(Self.sample))
    }

    @Test("Round-trips the empty model")
    func emptyModel() throws {
        let decoded = try MapGlobeCodec.decode(MapGlobeCodec.encode(MapGlobeModel()))
        #expect(decoded.fillVertices.isEmpty)
        #expect(decoded.fillIndices.isEmpty)
        #expect(decoded.borderSegments.isEmpty)
        #expect(decoded.drawOrder.isEmpty)
        #expect(decoded.countries.isEmpty)
    }

    @Test("Rejects a bad magic number")
    func badMagic() throws {
        var data = try MapGlobeCodec.encode(Self.sample)
        data[data.startIndex] ^= 0xFF
        #expect(throws: MapGlobeCodec.DecodeError.badMagic) {
            try MapGlobeCodec.decode(data)
        }
    }

    @Test("Rejects an unsupported version")
    func unsupportedVersion() throws {
        var data = try MapGlobeCodec.encode(Self.sample)
        var version = UInt32(99).littleEndian
        data.replaceSubrange(4 ..< 8, with: withUnsafeBytes(of: &version) { Data($0) })
        #expect(throws: MapGlobeCodec.DecodeError.unsupportedVersion(99)) {
            try MapGlobeCodec.decode(data)
        }
    }

    @Test("Rejects truncated data")
    func truncated() throws {
        let data = try MapGlobeCodec.encode(Self.sample).prefix(20)
        #expect(throws: BinaryDecodeError.truncated) {
            try MapGlobeCodec.decode(Data(data))
        }
    }

    @Test("Rejects data truncated at every possible offset")
    func truncatedEverywhere() throws {
        // Cutting inside every field class (header, bulk arrays, draw units, dictionary keys) must throw
        // and never crash. A cut landing exactly on the model boundary is impossible, since a prefix is
        // strictly shorter.
        let data = try MapGlobeCodec.encode(Self.sample)
        for length in 0 ..< data.count {
            #expect(throws: (any Error).self, "prefix of \(length) bytes should throw") {
                try MapGlobeCodec.decode(Data(data.prefix(length)))
            }
        }
    }

    @Test("A corrupt byte never crashes the decoder")
    func corruptByteNeverCrashes() throws {
        // Forcing each byte to 0xFF sweeps every failure class, including a count prefix inflated to
        // around 4 billion, which must throw up front rather than size a collection from it and die
        // allocating.
        let data = try MapGlobeCodec.encode(Self.sample)
        for index in 0 ..< data.count {
            var mutated = data
            mutated[index] = 0xFF
            _ = try? MapGlobeCodec.decode(mutated)
        }
    }

    @Test("Rejects trailing bytes after the model")
    func trailingData() throws {
        var data = try MapGlobeCodec.encode(Self.sample)
        data.append(contentsOf: [0xDE, 0xAD])
        #expect(throws: MapGlobeCodec.DecodeError.trailingData) {
            try MapGlobeCodec.decode(data)
        }
    }
}
