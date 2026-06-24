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
/// allocate, and the scalar wire format must stay in step between `append`, which writes by size, and
/// `read`, which advances by stride.
final class BinaryCodingTests: XCTestCase {
    private struct Entry: BinaryCodable, Equatable {
        var id: UInt32 = 0

        init() {}

        mutating func code(with coder: inout some BinaryCoder) throws {
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
    func testHostileElementCountThrowsInsteadOfAllocating() {
        var encoder = BinaryEncoder()
        encoder.append(UInt32.max)
        var decoder = BinaryDecoder(encoder.data)

        var array: [Entry] = []
        XCTAssertThrowsError(try decoder.elements(&array)) { error in
            XCTAssertEqual(error as? BinaryDecodeError, .truncated)
        }
        XCTAssertTrue(array.isEmpty)
    }

    func testHostileRangeCountThrowsInsteadOfAllocating() {
        var encoder = BinaryEncoder()
        encoder.append(UInt32.max)
        var decoder = BinaryDecoder(encoder.data)

        var ranges: [Range<Int>] = []
        XCTAssertThrowsError(try decoder.rangeArray(&ranges)) { error in
            XCTAssertEqual(error as? BinaryDecodeError, .truncated)
        }
        XCTAssertTrue(ranges.isEmpty)
    }

    func testHostileDictionaryCountThrowsInsteadOfAllocating() {
        var encoder = BinaryEncoder()
        encoder.append(UInt32.max)
        var decoder = BinaryDecoder(encoder.data)

        var dictionary: [String: Entry] = [:]
        XCTAssertThrowsError(try decoder.dictionary(&dictionary)) { error in
            XCTAssertEqual(error as? BinaryDecodeError, .truncated)
        }
        XCTAssertTrue(dictionary.isEmpty)
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

        var decoder = BinaryDecoder(data)
        var decoded: [Entry] = []
        XCTAssertThrowsError(try decoder.elements(&decoded)) { error in
            XCTAssertEqual(error as? BinaryDecodeError, .truncated)
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

        var decoder = BinaryDecoder(encoder.data)
        var decodedPadded = Padded()
        var decodedSentinel: UInt32 = 0
        try decoder.value(&decodedPadded)
        try decoder.value(&decodedSentinel)

        XCTAssertEqual(decodedPadded, padded)
        XCTAssertEqual(decodedSentinel, sentinel)
        XCTAssertTrue(decoder.isAtEnd)
    }

    func testIsAtEndFlipsOnlyOnceInputIsConsumed() throws {
        var encoder = BinaryEncoder()
        encoder.append(UInt32(42))
        encoder.append(UInt32(43))

        var decoder = BinaryDecoder(encoder.data)
        XCTAssertFalse(decoder.isAtEnd)
        XCTAssertEqual(try decoder.read() as UInt32, 42)
        XCTAssertFalse(decoder.isAtEnd)
        XCTAssertEqual(try decoder.read() as UInt32, 43)
        XCTAssertTrue(decoder.isAtEnd)
    }
}
