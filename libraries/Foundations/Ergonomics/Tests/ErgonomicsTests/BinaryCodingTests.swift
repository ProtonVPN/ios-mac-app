//
//  Created on 02.07.2026 by John Biggs.
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
import XCTest

/// The decode-hardening contracts of `BinaryCoding`: a corrupt length prefix must throw rather than
/// allocate, the scalar wire format must stay in step between `append`, which writes by size, and `read`,
/// which advances by stride, and aligned binary arrays must round-trip identically through the copying and
/// the zero-copy (blob slice) decode paths.
final class BinaryCodingTests: XCTestCase {
    private struct Entry: BinaryCodable, Equatable {
        var id: UInt32 = 0

        init() {}

        mutating func code(with coder: inout some BinaryCoder & ~Escapable) throws {
            try coder.value(&id)
        }
    }

    /// A UInt32 plus a UInt8 has size 5 but stride 8, the tail-padded shape the scalar path must round-trip.
    private struct Padded: Equatable {
        var id: UInt32 = 0
        var flag: UInt8 = 0
    }

    /// A count the remaining input can't possibly satisfy must throw `.truncated` up front. Sizing the
    /// destination collection from the raw count would turn one corrupt byte into a huge allocation and an
    /// out-of-memory crash instead of an error.
    func testHostileElementCountThrowsInsteadOfAllocating() throws {
        var encoder = BinaryEncoder()
        encoder.append(UInt32.max)

        try BinaryDecoder<InMemory>.decode(encoder.data) { decoder in
            var array: [Entry] = []
            XCTAssertThrowsError(try decoder.elements(&array)) { error in
                XCTAssertEqual(error as? BinaryDecodeError, .truncated)
            }
            XCTAssertTrue(array.isEmpty)
        }
    }

    func testHostileRangeCountThrowsInsteadOfAllocating() throws {
        var encoder = BinaryEncoder()
        encoder.append(UInt32.max)

        try BinaryDecoder<InMemory>.decode(encoder.data) { decoder in
            var ranges: [Range<Int>] = []
            XCTAssertThrowsError(try decoder.rangeArray(&ranges)) { error in
                XCTAssertEqual(error as? BinaryDecodeError, .truncated)
            }
            XCTAssertTrue(ranges.isEmpty)
        }
    }

    func testHostileDictionaryCountThrowsInsteadOfAllocating() throws {
        var encoder = BinaryEncoder()
        encoder.append(UInt32.max)

        try BinaryDecoder<InMemory>.decode(encoder.data) { decoder in
            var dictionary: [String: Entry] = [:]
            XCTAssertThrowsError(try decoder.dictionary(&dictionary)) { error in
                XCTAssertEqual(error as? BinaryDecodeError, .truncated)
            }
            XCTAssertTrue(dictionary.isEmpty)
        }
    }

    func testHostileBinaryArrayCountThrowsInsteadOfAllocating() throws {
        var encoder = BinaryEncoder()
        encoder.append(UInt32.max)

        try BinaryDecoder<InMemory>.decode(encoder.data) { decoder in
            var array = BinaryArray<UInt32, InMemory>()
            XCTAssertThrowsError(try decoder.binaryArray(&array, alignedTo: 16)) { error in
                XCTAssertEqual(error as? BinaryDecodeError, .truncated)
            }
            XCTAssertTrue(array.isEmpty)
        }
    }

    /// A plausible but oversized count, small enough to pass a naive sanity check yet larger than the
    /// input can hold, must also throw rather than allocate and partially fill.
    func testOversizedElementCountThrows() throws {
        var encoder = BinaryEncoder()
        var entries = [Entry](repeating: Entry(), count: 3)
        try encoder.elements(&entries)
        var data = encoder.data
        var inflated = UInt32(1000).littleEndian
        data.replaceSubrange(0 ..< 4, with: withUnsafeBytes(of: &inflated) { Data($0) })

        try BinaryDecoder<InMemory>.decode(data) { decoder in
            var decoded: [Entry] = []
            XCTAssertThrowsError(try decoder.elements(&decoded)) { error in
                XCTAssertEqual(error as? BinaryDecodeError, .truncated)
            }
        }
    }

    /// `append` writes a value's size but `read` advances its stride. The writer pads the difference so a
    /// tail-padded type can't silently desync every field written after it.
    func testTailPaddedValueStaysInStep() throws {
        var padded = Padded(id: 0xDECA_FBAD, flag: 7)
        var sentinel: UInt32 = 0xCAFE_D00D

        var encoder = BinaryEncoder()
        encoder.value(&padded)
        encoder.value(&sentinel)

        try BinaryDecoder<InMemory>.decode(encoder.data) { decoder in
            var decodedPadded = Padded()
            var decodedSentinel: UInt32 = 0
            try decoder.value(&decodedPadded)
            try decoder.value(&decodedSentinel)

            XCTAssertEqual(decodedPadded, padded)
            XCTAssertEqual(decodedSentinel, sentinel)
            XCTAssertTrue(decoder.isAtEnd)
        }
    }

    func testIsAtEndFlipsOnlyOnceInputIsConsumed() throws {
        var encoder = BinaryEncoder()
        encoder.append(UInt32(42))
        encoder.append(UInt32(43))

        try BinaryDecoder<InMemory>.decode(encoder.data) { decoder in
            XCTAssertFalse(decoder.isAtEnd)
            XCTAssertEqual(try decoder.read() as UInt32, 42)
            XCTAssertFalse(decoder.isAtEnd)
            XCTAssertEqual(try decoder.read() as UInt32, 43)
            XCTAssertTrue(decoder.isAtEnd)
        }
    }

    // MARK: - Aligned binary arrays

    /// The payload must start on the alignment boundary with deterministic zero padding before it, and the
    /// copying decode must walk the identical layout back out.
    func testBinaryArrayAlignsPayloadAndRoundTripsCopied() throws {
        var payload = BinaryArray<UInt32, InMemory>([1, 2, 3])
        var sentinel: UInt32 = 0xFEED_FACE

        var encoder = BinaryEncoder()
        encoder.append(UInt32(0xAA)) // knock the offset off the boundary first
        encoder.binaryArray(&payload, alignedTo: 64)
        encoder.value(&sentinel)

        // 4 (lead) + 4 (count), zero-padded to 64, then 12 payload + 4 sentinel bytes.
        XCTAssertEqual(encoder.data.count, 64 + 12 + 4)
        XCTAssertTrue(encoder.data[8 ..< 64].allSatisfy { $0 == 0 })

        try BinaryDecoder<InMemory>.decode(encoder.data) { decoder in
            XCTAssertEqual(try decoder.read() as UInt32, 0xAA)
            var decoded = BinaryArray<UInt32, InMemory>()
            try decoder.binaryArray(&decoded, alignedTo: 64)
            XCTAssertEqual(decoded.elements, [1, 2, 3]) // the copying path owns its elements
            var end: UInt32 = 0
            try decoder.value(&end)
            XCTAssertEqual(end, sentinel)
            XCTAssertTrue(decoder.isAtEnd)
        }
    }

    /// The zero-copy path must consume the identical layout the copying path does and hand back aligned
    /// slices that resolve to the encoded elements. Together with the copying round-trip above, which
    /// proves encode and decode are exact inverses, this pins the sliced decoder's offset bookkeeping
    /// without ever needing to write a slice back out.
    func testBinaryArraySlicedDecodeResolvesAlignedSlicesInPlace() throws {
        var payload = BinaryArray<UInt32, InMemory>([7, 8, 9, 10])
        var encoder = BinaryEncoder()
        encoder.binaryArray(&payload, alignedTo: 32)
        let data = encoder.data

        let url = FileManager.default.temporaryDirectory.appendingPathComponent("bulk-\(UUID().uuidString).bin")
        try data.write(to: url)
        defer { try? FileManager.default.removeItem(at: url) }
        let mapping = try MmapBuffer(readingPath: url.path)

        let decoded: BinaryArray<UInt32, Mapped> = try mapping.withRawSpan { blob in
            try BinaryDecoder<Mapped>.decode(slicing: blob) { decoder in
                var array = BinaryArray<UInt32, Mapped>()
                try decoder.binaryArray(&array, alignedTo: 32)
                XCTAssertTrue(decoder.isAtEnd) // the sliced traversal consumed exactly the encoded layout
                return array
            }
        }

        let region = decoded.blobSliceRegion
        XCTAssertEqual(region.byteOffset % 32, 0)
        XCTAssertEqual(region.byteCount, 16)

        mapping.withUnsafeBytes { blob in
            XCTAssertEqual(decoded.elements(in: blob), [7, 8, 9, 10])
        }
        try mapping.withRawSpan { blob in
            let sum = decoded.withSpan(in: blob) { span in
                var total = 0
                for index in span.indices {
                    total += Int(span[index])
                }
                return total
            }
            XCTAssertEqual(sum, 34)
        }
    }

    /// An empty binary array decodes to owned storage even on the zero-copy path, so it resolves anywhere
    /// with no blob at all.
    func testEmptyBinaryArrayStaysOwnedInSlicedMode() throws {
        var empty = BinaryArray<UInt32, InMemory>()
        var encoder = BinaryEncoder()
        encoder.binaryArray(&empty, alignedTo: 16)

        try encoder.data.withUnsafeBytes { bytes in
            try BinaryDecoder<Mapped>.decode(slicing: bytes.bytes) { decoder in
                var array = BinaryArray<UInt32, Mapped>()
                try decoder.binaryArray(&array, alignedTo: 16)
                XCTAssertTrue(array.isEmpty)
                XCTAssertEqual(array.blobSliceRegion.byteCount, 0)
                XCTAssertEqual(array.elements(in: bytes), [])
                XCTAssertTrue(decoder.isAtEnd)
            }
        }
    }

    /// A cut inside the alignment padding is truncation like any other, thrown before the offset moves.
    func testBinaryArrayTruncatedInsidePaddingThrows() throws {
        var payload = BinaryArray<UInt32, InMemory>([5])
        var encoder = BinaryEncoder()
        encoder.binaryArray(&payload, alignedTo: 64)

        let truncated = encoder.data.prefix(10) // count survives, the pad does not
        try BinaryDecoder<InMemory>.decode(Data(truncated)) { decoder in
            var array = BinaryArray<UInt32, InMemory>()
            XCTAssertThrowsError(try decoder.binaryArray(&array, alignedTo: 64)) { error in
                XCTAssertEqual(error as? BinaryDecodeError, .truncated)
            }
        }
    }
}
