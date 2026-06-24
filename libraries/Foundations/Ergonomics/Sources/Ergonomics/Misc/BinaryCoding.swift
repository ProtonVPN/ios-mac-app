//
//  Created on 19/06/2026.
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

import Foundation

/// Raised when a binary blob ends before the reader expected: a truncated or corrupt resource.
public enum BinaryDecodeError: Error, Equatable {
    case truncated
}

// MARK: - BinaryCoder

/// A simple protocol to support two-way binary encoding/decoding. Types conform to ``BinaryCodable`` and implement
/// `init` and `code(_:)` methods, and can then use both ``BinaryEncoder`` and ``BinaryDecoder`` for serialization.
/// Values are constrained to `BitwiseCopyable` in order to keep decoding fast, essentially relying on plain `memcpy`.
/// Because `code(_:)` captures the order of the field list, the encoder and decoder can't drift out of step.
public protocol BinaryCoder {
    /// `true` while decoding. Composite helpers read it to grow a collection before they fill it. The
    /// encoder, which already holds the elements, leaves it `false`.
    var isReading: Bool { get }

    /// Bytes still available to read, or `.max` when encoding, since the writer has no bound. Composite
    /// helpers check length prefixes against it before allocating, so a corrupt count throws instead of
    /// exhausting memory.
    var remainingByteCount: Int { get }

    /// One fixed-size data value (a scalar, a SIMD vector, a color, a segment).
    mutating func value(_ value: inout some BitwiseCopyable) throws
    /// A length-prefixed array, moved in a single bulk copy.
    mutating func bulkArray(_ array: inout [some BitwiseCopyable]) throws
    /// A length-prefixed UTF-8 string (`UInt32` byte count + bytes).
    mutating func string(_ string: inout String) throws
}

public extension BinaryCoder {
    /// A half-open `Range<Int>` as its lower bound and count, two `UInt32`s. Symmetric with no branch: the
    /// arithmetic rebuilds `range` identically whether we just read the parts or are about to write them.
    mutating func range(_ range: inout Range<Int>) throws {
        var lower = UInt32(range.lowerBound)
        var count = UInt32(range.count)
        try value(&lower)
        try value(&count)
        range = Int(lower) ..< (Int(lower) + Int(count))
    }

    /// A length-prefixed array of `Range<Int>`.
    mutating func rangeArray(_ ranges: inout [Range<Int>]) throws {
        var count = UInt32(ranges.count)
        try value(&count)
        if isReading {
            try validate(count: count, minimumBytesPerElement: 8) // lowerBound + count, two UInt32s
            ranges = Array(repeating: 0 ..< 0, count: Int(count))
        }
        for index in ranges.indices {
            try range(&ranges[index])
        }
    }

    /// A length-prefixed array of nested codable elements.
    mutating func elements<Element: BinaryCodable>(_ array: inout [Element]) throws {
        var count = UInt32(array.count)
        try value(&count)
        if isReading {
            try validate(count: count, minimumBytesPerElement: 1)
            array = (0 ..< Int(count)).map { _ in Element() }
        }
        for index in array.indices {
            try array[index].code(with: &self)
        }
    }

    /// A `[String: Value]` dictionary written in sorted-key order, so the baked binary is reproducible.
    mutating func dictionary<Value: BinaryCodable>(_ dictionary: inout [String: Value]) throws {
        var count = UInt32(dictionary.count)
        try value(&count)
        if isReading {
            try validate(count: count, minimumBytesPerElement: 4) // every entry starts with a key length prefix
            dictionary = Dictionary(minimumCapacity: Int(count))
            for _ in 0 ..< Int(count) {
                var key = ""
                try string(&key)
                var element = Value()
                try element.code(with: &self)
                dictionary[key] = element
            }
        } else {
            for key in dictionary.keys.sorted() {
                var key = key
                var element = dictionary[key]!
                try string(&key)
                try element.code(with: &self)
            }
        }
    }

    /// Rejects a corrupt length prefix before anything is allocated from it: `count` elements need at
    /// least `count * minimumBytesPerElement` more input, so a count the remaining bytes can't possibly
    /// satisfy is truncation, thrown here rather than surfacing as a multi-gigabyte allocation.
    private func validate(count: UInt32, minimumBytesPerElement: Int) throws {
        guard Int(count) <= remainingByteCount / minimumBytesPerElement else { throw BinaryDecodeError.truncated }
    }
}

// MARK: - BinaryCodable

/// A type that serialises itself through one `code(with:)` traversal shared by both directions. The blank
/// `init()` gives the decoder an instance to fill before it starts reading.
public protocol BinaryCodable {
    init()
    mutating func code(with coder: inout some BinaryCoder) throws
}

// MARK: - BinaryEncoder

/// Little-endian binary writer: tightly packed data with no padding between fields. Encoding never fails,
/// so its `BinaryCoder` methods are non-throwing, which still satisfies the throwing requirement.
public struct BinaryEncoder: BinaryCoder {
    public init() {}

    public private(set) var data = Data()

    public var isReading: Bool {
        false
    }

    public var remainingByteCount: Int {
        .max
    }

    public mutating func value(_ value: inout some BitwiseCopyable) {
        append(value)
    }

    public mutating func bulkArray(_ array: inout [some BitwiseCopyable]) {
        append(UInt32(array.count))
        array.withUnsafeBytes { data.append(contentsOf: $0) }
    }

    public mutating func string(_ string: inout String) {
        let bytes = Array(string.utf8)
        append(UInt32(bytes.count))
        data.append(contentsOf: bytes)
    }

    /// Raw little-endian append of one bitwise copyable value, padded out to the type's stride so it stays
    /// in step with `BinaryDecoder.read`, which advances by stride. Every type currently on the wire has
    /// size equal to stride, so the padding is zero bytes. This guards the first type that gains tail
    /// padding.
    public mutating func append(_ value: some BitwiseCopyable) {
        withUnsafeBytes(of: value) { data.append(contentsOf: $0) }
        let padding = MemoryLayout.stride(ofValue: value) - MemoryLayout.size(ofValue: value)
        if padding > 0 { data.append(contentsOf: repeatElement(0, count: padding)) }
    }
}

// MARK: - BinaryDecoder

/// Little-endian binary reader mirroring `BinaryEncoder`. Bulk arrays are `memcpy`-ed in one shot.
public struct BinaryDecoder: BinaryCoder {
    private let data: Data
    /// Byte offset into `data`'s contents, 0-based to match the `withUnsafeBytes` buffer, whose index 0 is
    /// always `data`'s first byte regardless of the `Data`'s own `startIndex`.
    private var offset = 0

    public init(_ data: Data) {
        self.data = data
    }

    public var isReading: Bool {
        true
    }

    public var remainingByteCount: Int {
        data.count - offset
    }

    /// `true` once every input byte has been consumed. Callers that expect to own the whole blob, like
    /// file codecs, check this after decoding. Trailing bytes mean a corrupt file or a desynced reader.
    public var isAtEnd: Bool {
        offset == data.count
    }

    public mutating func value(_ value: inout some BitwiseCopyable) throws {
        value = try read()
    }

    public mutating func bulkArray(_ array: inout [some BitwiseCopyable]) throws {
        array = try readArray()
    }

    public mutating func string(_ string: inout String) throws {
        string = try readString()
    }

    /// Raw little-endian read of one data value.
    public mutating func read<T: BitwiseCopyable>() throws -> T {
        let stride = MemoryLayout<T>.stride
        try require(stride)
        let value = data.withUnsafeBytes { raw in
            raw.loadUnaligned(fromByteOffset: offset, as: T.self)
        }
        offset += stride
        return value
    }

    /// Bulk-reads a length-prefixed array via a single `memcpy`.
    public mutating func readArray<T: BitwiseCopyable>() throws -> [T] {
        let count = try Int(read() as UInt32)
        let byteCount = count * MemoryLayout<T>.stride
        try require(byteCount)
        let start = offset
        let result = [T](unsafeUninitializedCapacity: count) { buffer, initialized in
            if byteCount > 0 {
                data.withUnsafeBytes { raw in
                    let source = UnsafeRawBufferPointer(rebasing: raw[start ..< (start + byteCount)])
                    UnsafeMutableRawBufferPointer(buffer).copyMemory(from: source)
                }
            }
            initialized = count
        }
        offset += byteCount
        return result
    }

    public mutating func readString() throws -> String {
        let length = try Int(read() as UInt32)
        try require(length)
        let start = offset
        let string = data.withUnsafeBytes { raw -> String in
            String(decoding: UnsafeRawBufferPointer(rebasing: raw[start ..< (start + length)]), as: UTF8.self)
        }
        offset += length
        return string
    }

    private func require(_ bytes: Int) throws {
        if offset + bytes > data.count { throw BinaryDecodeError.truncated }
    }
}
