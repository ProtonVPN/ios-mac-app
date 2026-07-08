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
import Foundation
import Testing

/// The decode-hardening contracts of `BinaryCoding`: a corrupt length prefix must throw rather than
/// allocate, the scalar wire format must stay in step between `append`, which writes by size, and `read`,
/// which advances by stride, and aligned binary arrays must round-trip identically through the copying and
/// the zero-copy (blob slice) decode paths.
@Suite("Binary coding")
struct BinaryCodingTests {
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

    /// `#expect` decomposes a member access into `__checkPropertyAccess`, which requires the base be
    /// `Escapable`; the decoder is `~Escapable`, so route its `isAtEnd` through a plain `Bool` here.
    private func expectAtEnd(
        _ isAtEnd: Bool,
        is expected: Bool,
        sourceLocation: SourceLocation = #_sourceLocation
    ) {
        #expect(isAtEnd == expected, sourceLocation: sourceLocation)
    }

    /// A count the remaining input can't possibly satisfy must throw `.truncated` up front. Sizing the
    /// destination collection from the raw count would turn one corrupt byte into a huge allocation and an
    /// out-of-memory crash instead of an error.
    @Test("A hostile element count throws instead of allocating")
    func hostileElementCountThrowsInsteadOfAllocating() throws {
        var encoder = BinaryEncoder()
        encoder.append(UInt32.max)

        try BinaryDecoder<InMemory>.decode(encoder.data) { decoder in
            var array: [Entry] = []
            #expect(throws: BinaryDecodeError.truncated) {
                try decoder.elements(&array)
            }
            #expect(array.isEmpty)
        }
    }

    @Test("A hostile range count throws instead of allocating")
    func hostileRangeCountThrowsInsteadOfAllocating() throws {
        var encoder = BinaryEncoder()
        encoder.append(UInt32.max)

        try BinaryDecoder<InMemory>.decode(encoder.data) { decoder in
            var ranges: [Range<Int>] = []
            #expect(throws: BinaryDecodeError.truncated) {
                try decoder.rangeArray(&ranges)
            }
            #expect(ranges.isEmpty)
        }
    }

    @Test("A hostile dictionary count throws instead of allocating")
    func hostileDictionaryCountThrowsInsteadOfAllocating() throws {
        var encoder = BinaryEncoder()
        encoder.append(UInt32.max)

        try BinaryDecoder<InMemory>.decode(encoder.data) { decoder in
            var dictionary: [String: Entry] = [:]
            #expect(throws: BinaryDecodeError.truncated) {
                try decoder.dictionary(&dictionary)
            }
            #expect(dictionary.isEmpty)
        }
    }

    @Test("A hostile binary-array count throws instead of allocating")
    func hostileBinaryArrayCountThrowsInsteadOfAllocating() throws {
        var encoder = BinaryEncoder()
        encoder.append(UInt32.max)

        try BinaryDecoder<InMemory>.decode(encoder.data) { decoder in
            var array = BinaryArray<UInt32, InMemory>()
            #expect(throws: BinaryDecodeError.truncated) {
                try decoder.binaryArray(&array, alignedTo: 16)
            }
            #expect(array.isEmpty)
        }
    }

    /// A plausible but oversized count, small enough to pass a naive sanity check yet larger than the
    /// input can hold, must also throw rather than allocate and partially fill.
    @Test("An oversized element count throws")
    func oversizedElementCountThrows() throws {
        var encoder = BinaryEncoder()
        var entries = [Entry](repeating: Entry(), count: 3)
        try encoder.elements(&entries)
        var data = encoder.data
        var inflated = UInt32(1000).littleEndian
        data.replaceSubrange(0 ..< 4, with: withUnsafeBytes(of: &inflated) { Data($0) })

        try BinaryDecoder<InMemory>.decode(data) { decoder in
            var decoded: [Entry] = []
            #expect(throws: BinaryDecodeError.truncated) {
                try decoder.elements(&decoded)
            }
        }
    }

    /// `append` writes a value's size but `read` advances its stride. The writer pads the difference so a
    /// tail-padded type can't silently desync every field written after it.
    @Test("A tail-padded value stays in step")
    func tailPaddedValueStaysInStep() throws {
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

            #expect(decodedPadded == padded)
            #expect(decodedSentinel == sentinel)
            expectAtEnd(decoder.isAtEnd, is: true)
        }
    }

    @Test("isAtEnd flips only once input is consumed")
    func isAtEndFlipsOnlyOnceInputIsConsumed() throws {
        var encoder = BinaryEncoder()
        encoder.append(UInt32(42))
        encoder.append(UInt32(43))

        try BinaryDecoder<InMemory>.decode(encoder.data) { decoder in
            expectAtEnd(decoder.isAtEnd, is: false)
            let first = try decoder.read() as UInt32
            #expect(first == 42)
            expectAtEnd(decoder.isAtEnd, is: false)
            let second = try decoder.read() as UInt32
            #expect(second == 43)
            expectAtEnd(decoder.isAtEnd, is: true)
        }
    }

    // MARK: - Aligned binary arrays

    /// The payload must start on the alignment boundary with deterministic zero padding before it, and the
    /// copying decode must walk the identical layout back out.
    @Test("A binary array aligns its payload and round-trips copied")
    func binaryArrayAlignsPayloadAndRoundTripsCopied() throws {
        var payload = BinaryArray<UInt32, InMemory>([1, 2, 3])
        var sentinel: UInt32 = 0xFEED_FACE

        var encoder = BinaryEncoder()
        encoder.append(UInt32(0xAA)) // knock the offset off the boundary first
        encoder.binaryArray(&payload, alignedTo: 64)
        encoder.value(&sentinel)

        // 4 (lead) + 4 (count), zero-padded to 64, then 12 payload + 4 sentinel bytes.
        #expect(encoder.data.count == 64 + 12 + 4)
        #expect(encoder.data[8 ..< 64].allSatisfy { $0 == 0 })

        try BinaryDecoder<InMemory>.decode(encoder.data) { decoder in
            let lead = try decoder.read() as UInt32
            #expect(lead == 0xAA)
            var decoded = BinaryArray<UInt32, InMemory>()
            try decoder.binaryArray(&decoded, alignedTo: 64)
            #expect(decoded.elements == [1, 2, 3]) // the copying path owns its elements
            var end: UInt32 = 0
            try decoder.value(&end)
            #expect(end == sentinel)
            expectAtEnd(decoder.isAtEnd, is: true)
        }
    }

    /// The zero-copy path must consume the identical layout the copying path does and hand back aligned
    /// slices that resolve to the encoded elements. Together with the copying round-trip above, which
    /// proves encode and decode are exact inverses, this pins the sliced decoder's offset bookkeeping
    /// without ever needing to write a slice back out.
    @Test("A sliced decode resolves aligned slices in place")
    func binaryArraySlicedDecodeResolvesAlignedSlicesInPlace() throws {
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
                expectAtEnd(decoder.isAtEnd, is: true) // the sliced traversal consumed exactly the encoded layout
                return array
            }
        }

        let region = decoded.blobSliceRegion
        #expect(region.byteOffset % 32 == 0)
        #expect(region.byteCount == 16)

        mapping.withUnsafeBytes { blob in
            #expect(decoded.elements(in: blob) == [7, 8, 9, 10])
        }
        try mapping.withRawSpan { blob in
            let sum = decoded.withSpan(in: blob) { span in
                var total = 0
                for index in span.indices {
                    total += Int(span[index])
                }
                return total
            }
            #expect(sum == 34)
        }
    }

    /// An empty binary array decodes to owned storage even on the zero-copy path, so it resolves anywhere
    /// with no blob at all.
    @Test("An empty binary array stays owned in sliced mode")
    func emptyBinaryArrayStaysOwnedInSlicedMode() throws {
        var empty = BinaryArray<UInt32, InMemory>()
        var encoder = BinaryEncoder()
        encoder.binaryArray(&empty, alignedTo: 16)

        try encoder.data.withUnsafeBytes { bytes in
            try BinaryDecoder<Mapped>.decode(slicing: bytes.bytes) { decoder in
                var array = BinaryArray<UInt32, Mapped>()
                try decoder.binaryArray(&array, alignedTo: 16)
                #expect(array.isEmpty)
                #expect(array.blobSliceRegion.byteCount == 0)
                #expect(array.elements(in: bytes) == [])
                expectAtEnd(decoder.isAtEnd, is: true)
            }
        }
    }

    /// A cut inside the alignment padding is truncation like any other, thrown before the offset moves.
    @Test("A binary array truncated inside its padding throws")
    func binaryArrayTruncatedInsidePaddingThrows() throws {
        var payload = BinaryArray<UInt32, InMemory>([5])
        var encoder = BinaryEncoder()
        encoder.binaryArray(&payload, alignedTo: 64)

        let truncated = encoder.data.prefix(10) // count survives, the pad does not
        try BinaryDecoder<InMemory>.decode(Data(truncated)) { decoder in
            var array = BinaryArray<UInt32, InMemory>()
            #expect(throws: BinaryDecodeError.truncated) {
                try decoder.binaryArray(&array, alignedTo: 64)
            }
        }
    }
}
