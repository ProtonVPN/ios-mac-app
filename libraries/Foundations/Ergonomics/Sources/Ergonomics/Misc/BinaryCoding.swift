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

// MARK: - Binary storage backing

/// The half of a storage marker the decoder dispatches on: how to materialise a span of elements that the traversal has
/// just walked past. Static and specialized so the decoder always agrees with its type-safe `Storage`.
public protocol BinaryBacking {
    /// Creates the array whose payload occupies `byteOffset ..< byteOffset + count * stride` within `bytes`: `InMemory`
    /// copies the elements out, `Mapped` records the offsets.
    static func makeBinaryArray<Element: BitwiseCopyable>(
        from bytes: RawSpan,
        byteOffset: Int,
        count: Int
    ) -> BinaryArray<Element, Self>
}

public enum InMemory: BinaryBacking {
    public static func makeBinaryArray<Element: BitwiseCopyable>(
        from bytes: RawSpan,
        byteOffset: Int,
        count: Int
    ) -> BinaryArray<Element, InMemory> {
        let region = bytes.extracting(byteOffset ..< byteOffset + count * MemoryLayout<Element>.stride)
        return BinaryArray(backing: .owned(copyElements(from: region, count: count)))
    }
}

public enum Mapped: BinaryBacking {
    public static func makeBinaryArray<Element: BitwiseCopyable>(
        from _: RawSpan,
        byteOffset: Int,
        count: Int
    ) -> BinaryArray<Element, Mapped> {
        count > 0 ? BinaryArray(backing: .blobSlice(byteOffset: byteOffset, count: count)) : BinaryArray()
    }
}

// MARK: - BinaryArray

/// A length-prefixed bulk payload. `Storage` picks the representation: `InMemory` holds the elements (the encode side,
/// and copying decodes), `Mapped` holds only an offset and count into the source blob. A slice is resolved against the
/// blob's bytes at each use, inside whatever scoped borrow the blob's owner provides.
public struct BinaryArray<Element: BitwiseCopyable, Storage: BinaryBacking> {
    /// Always matches `Storage`: `owned` represents the `InMemory` case whereas `blobSlice` represents `Mapped`.
    enum Backing {
        case owned([Element])
        case blobSlice(byteOffset: Int, count: Int)
        case empty
    }

    let backing: Backing

    init(backing: Backing) {
        self.backing = backing
    }

    /// The empty array, valid under any storage marker: the decode traversal's seed and the natural zero.
    public init() {
        self.backing = .empty
    }

    public var count: Int {
        switch backing {
        case let .owned(elements): elements.count
        case let .blobSlice(_, count): count
        case .empty: 0
        }
    }

    public var isEmpty: Bool {
        count == 0
    }
}

extension BinaryArray: Sendable where Element: Sendable {}

public extension BinaryArray where Storage == InMemory {
    init(_ elements: [Element]) {
        self.init(backing: .owned(elements))
    }

    /// The owned elements, as-is. The storage-neutral empty resolves to the empty array, so encoding a freshly seeded
    /// model never trips over it.
    var elements: [Element] {
        switch backing {
        case let .owned(elements): elements
        case .empty: []
        case .blobSlice: preconditionFailure("Owned storage must be resolvable for InMemory storage arrays (in \(#function))")
        }
    }

    /// Contiguous element access without copying.
    func withUnsafeBufferPointer<R>(_ body: (UnsafeBufferPointer<Element>) throws -> R) rethrows -> R {
        try elements.withUnsafeBufferPointer(body)
    }

    /// Scoped, compiler-checked access to the elements as a `Span`: a span cannot escape `body`, so the no-escape rule
    /// is enforced rather than documented.
    func withSpan<R>(_ body: (Span<Element>) throws -> R) rethrows -> R {
        try elements.withUnsafeBufferPointer { try body($0.span) }
    }
}

public extension BinaryArray where Storage == Mapped {
    /// The slice's byte region within the source blob. Plain offsets: what lets a consumer that has adopted the whole
    /// blob (like a GPU no-copy buffer over the mapping) address this array without any copy or pointer hand-off. The
    /// empty array reports a zero-length region at offset 0.
    var blobSliceRegion: (byteOffset: Int, byteCount: Int) {
        switch backing {
        case let .blobSlice(byteOffset, count): (byteOffset, count * MemoryLayout<Element>.stride)
        case .empty: (0, 0) // storage-neutral empty
        case .owned: preconditionFailure("A blob slice must be resolvable for Mapped storage arrays (in \(#function))")
        }
    }

    /// Contiguous element access without copying, resolved against the blob this slice was decoded from. A slice
    /// reaching outside `blob` (the wrong blob, or a truncated one) traps instead of misreading.
    func withUnsafeBufferPointer<R>(
        in blob: UnsafeRawBufferPointer,
        _ body: (UnsafeBufferPointer<Element>) throws -> R
    ) rethrows -> R {
        guard case let .blobSlice(byteOffset, count) = backing else { // storage-neutral empty
            return try body(UnsafeBufferPointer(start: nil, count: 0))
        }
        guard let base = blob.baseAddress, byteOffset + count * MemoryLayout<Element>.stride <= blob.count else {
            preconditionFailure("A blob slice must be resolved against the blob it was decoded from")
        }
        let start = (base + byteOffset).bindMemory(to: Element.self, capacity: count)
        return try body(UnsafeBufferPointer(start: start, count: count))
    }

    /// Scoped, compiler-checked access to the elements as a `Span`, resolving this slice against the blob it was
    /// decoded from. A slice reaching outside `blob` traps in `extracting`.
    func withSpan<R>(in blob: RawSpan, _ body: (Span<Element>) throws -> R) rethrows -> R {
        guard case let .blobSlice(byteOffset, count) = backing else { // storage-neutral empty
            return try body(UnsafeBufferPointer(start: nil, count: 0).span)
        }
        let region = blob.extracting(byteOffset ..< byteOffset + count * MemoryLayout<Element>.stride)
        return try region.withUnsafeBytes { raw in
            let start = raw.baseAddress!.bindMemory(to: Element.self, capacity: count)
            return try body(UnsafeBufferPointer(start: start, count: count).span)
        }
    }

    /// The elements copied out of `blob`, under the same contract as `withUnsafeBufferPointer(in:)`.
    func elements(in blob: UnsafeRawBufferPointer) -> [Element] {
        withUnsafeBufferPointer(in: blob, Array.init)
    }
}

/// Copies `count` elements out of `region` in one `memcpy`. Shared by the in-memory bulk strategy and the decoder's
/// plain array reads; the caller has already bounds-checked the region.
func copyElements<Element: BitwiseCopyable>(from region: RawSpan, count: Int) -> [Element] {
    region.withUnsafeBytes { raw in
        [Element](unsafeUninitializedCapacity: count) { buffer, initialized in
            if count > 0 {
                UnsafeMutableRawBufferPointer(buffer).copyMemory(from: raw)
            }
            initialized = count
        }
    }
}

// MARK: - BinaryCoder

/// A simple protocol to support two-way binary encoding/decoding. Types conform to ``BinaryCodable`` and implement
/// `init` and `code(_:)` methods, and can then use both ``BinaryEncoder`` and ``BinaryDecoder`` for serialization.
/// Values are constrained to `BitwiseCopyable` in order to keep decoding fast, essentially relying on plain `memcpy`.
/// Because `code(_:)` captures the order of the field list, the encoder and decoder can't drift out of step.
/// `~Escapable`-suppressed so the decoder, a nonescapable span cursor, can conform alongside the plain escapable
/// encoder. `Storage` pins which bulks a coder can legally fill or consume: the encoder and the copying decoder speak
/// `InMemory`, the zero-copy decoder speaks `Mapped`, and crossing certain methods is regarded as a type error.
public protocol BinaryCoder<Storage>: ~Escapable {
    associatedtype Storage: BinaryBacking

    /// `true` while decoding. Composite helpers read it to grow a collection before they fill it. The encoder, which
    /// already holds the elements, leaves it `false`.
    var isReading: Bool { get }

    /// Bytes still available to read, or `.max` when encoding, since the writer has no bound. Composite helpers check
    /// length prefixes against it before allocating, so a corrupt count throws instead of exhausting memory.
    var remainingByteCount: Int { get }

    /// One fixed-size data value (a scalar, a SIMD vector, a color, a segment).
    mutating func value(_ value: inout some BitwiseCopyable) throws

    /// A length-prefixed array, moved in a single bulk copy.
    mutating func binaryArray(_ array: inout [some BitwiseCopyable]) throws

    /// A length-prefixed array payload whose bytes start on a multiple of `alignment` from the blob's start. A decoder
    /// built over a retained page-aligned mapping can then hand the payload back as a zero-copy slice that a GPU binds
    /// to. `alignment` must be at least the element type's alignment.
    mutating func binaryArray(
        _ array: inout BinaryArray<some BitwiseCopyable, Storage>,
        alignedTo alignment: Int
    ) throws

    /// A length-prefixed UTF-8 string (`UInt32` byte count + bytes).
    mutating func string(_ string: inout String) throws
}

public extension BinaryCoder where Self: ~Escapable {
    /// A half-open `Range<Int>` as its lower bound and count, two `UInt32`s. Symmetric with no branch: the arithmetic
    /// rebuilds `range` identically whether we just read the parts or are about to write them.
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

    /// Rejects a corrupt length prefix before anything is allocated from it: `count` elements need at least `count *
    /// minimumBytesPerElement` more input, so the remaining bytes can't possibly satisfy is truncation, thrown here
    /// rather than creating a multi-gigabyte allocation.
    private func validate(count: UInt32, minimumBytesPerElement: Int) throws {
        guard Int(count) <= remainingByteCount / minimumBytesPerElement else { throw BinaryDecodeError.truncated }
    }
}

// MARK: - BinaryCodable

/// A type that serialises itself through one `code(with:)` traversal shared by both directions. The blank `init()`
/// gives the decoder an instance to fill before it starts reading.
public protocol BinaryCodable {
    init()
    mutating func code(with coder: inout some BinaryCoder & ~Escapable) throws
}

// MARK: - BinaryEncoder

/// Little-endian binary writer: tightly packed data with no padding between fields, except the explicit alignment
/// padding of `binaryArray(_:alignedTo:)` payloads. Encoding never fails, assuming enough memory exists.
public struct BinaryEncoder: BinaryCoder {
    /// Writing consumes elements that exist in memory, so only `InMemory` backings can ever reach the encoder. A
    /// zero-copy model is a read-only view of an existing file and shouldn't need to re-encode.
    public typealias Storage = InMemory

    public private(set) var data = Data()

    public init() {}

    public var isReading: Bool {
        false
    }

    public var remainingByteCount: Int {
        .max
    }

    public mutating func value(_ value: inout some BitwiseCopyable) {
        append(value)
    }

    public mutating func binaryArray(_ array: inout [some BitwiseCopyable]) {
        append(UInt32(array.count))
        array.withUnsafeBytes { data.append(contentsOf: $0) }
    }

    public mutating func binaryArray<Element: BitwiseCopyable>(
        _ array: inout BinaryArray<Element, InMemory>,
        alignedTo alignment: Int
    ) {
        precondition(alignment >= MemoryLayout<Element>.alignment, "alignment must satisfy the element type")

        append(UInt32(array.count))
        // Alignment is measured from the start of the encoded blob, which is also where a decoder's blob begins, so the
        // two sides compute identical padding.
        let misalignment = data.count % alignment
        if misalignment > 0 { data.append(contentsOf: repeatElement(0, count: alignment - misalignment)) }
        array.withUnsafeBufferPointer { data.append(contentsOf: UnsafeRawBufferPointer($0)) }
    }

    public mutating func string(_ string: inout String) {
        let bytes = Array(string.utf8)
        append(UInt32(bytes.count))
        data.append(contentsOf: bytes)
    }

    /// Raw little-endian append of one bitwise copyable value, padded out to the type's stride so it stays in step with
    /// `BinaryDecoder.read`, which advances by stride. Every type currently on the wire has size equal to stride, so
    /// the padding is zero bytes. This guards the first type that gains tail padding.
    public mutating func append(_ value: some BitwiseCopyable) {
        withUnsafeBytes(of: value) { data.append(contentsOf: $0) }
        let padding = MemoryLayout.stride(ofValue: value) - MemoryLayout.size(ofValue: value)
        if padding > 0 { data.append(contentsOf: repeatElement(0, count: padding)) }
    }
}

// MARK: - BinaryDecoder

/// Little-endian binary reader mirroring `BinaryEncoder`, walking a single span of memory. Since the decoder stores the
/// `RawSpan` it reads the compiler can tie every decoder to the borrow that produced its bytes and the whole traversal
/// is lifetime-checked. `Storage` is a generic type that lets us be typesafe about standalone copies (`InMemory`)
/// versus offset slices into a memory-mapped blob (`Mapped`).
public struct BinaryDecoder<Storage: BinaryBacking>: BinaryCoder, ~Escapable {
    private let bytes: RawSpan
    /// Byte offset into `bytes`, which always begins at the blob's first byte, so offsets recorded into blob slices are
    /// also offsets into the caller's blob.
    private var offset = 0

    @_lifetime(copy blob)
    private init(bytes blob: consuming RawSpan) {
        self.bytes = blob
    }

    public var isReading: Bool {
        true
    }

    public var remainingByteCount: Int {
        bytes.byteCount - offset
    }

    /// `true` once every input byte has been consumed. Callers that expect to own the whole blob, like
    /// file codecs, check this after decoding. Trailing bytes mean a corrupt file or a desynced reader.
    public var isAtEnd: Bool {
        offset == bytes.byteCount
    }

    public mutating func value(_ value: inout some BitwiseCopyable) throws {
        value = try read()
    }

    public mutating func binaryArray(_ array: inout [some BitwiseCopyable]) throws {
        array = try readArray()
    }

    public mutating func binaryArray<Element: BitwiseCopyable>(_ array: inout BinaryArray<Element, Storage>, alignedTo alignment: Int) throws {
        precondition(alignment >= MemoryLayout<Element>.alignment, "alignment must satisfy the element type")
        let count = try Int(read() as UInt32)
        let misalignment = offset % alignment
        let padding = misalignment > 0 ? alignment - misalignment : 0
        let byteCount = count * MemoryLayout<Element>.stride
        try require(padding + byteCount)
        offset += padding
        array = Storage.makeBinaryArray(from: bytes, byteOffset: offset, count: count)
        offset += byteCount
    }

    public mutating func string(_ string: inout String) throws {
        string = try readString()
    }

    /// Raw little-endian read of one data value.
    public mutating func read<T: BitwiseCopyable>() throws -> T {
        let stride = MemoryLayout<T>.stride
        try require(stride)
        let value = bytes.unsafeLoadUnaligned(fromByteOffset: offset, as: T.self)
        offset += stride
        return value
    }

    /// Bulk-reads a length-prefixed array via a single `memcpy`.
    public mutating func readArray<T: BitwiseCopyable>() throws -> [T] {
        let count = try Int(read() as UInt32)
        try require(count * MemoryLayout<T>.stride)
        return readElements(count: count)
    }

    public mutating func readString() throws -> String {
        let length = try Int(read() as UInt32)
        try require(length)
        let region = bytes.extracting(offset ..< offset + length)
        offset += length
        return region.withUnsafeBytes { raw in
            String(decoding: raw, as: UTF8.self)
        }
    }

    /// Copies `count` elements out of the input, which `require` has already vouched for, in one `memcpy`.
    private mutating func readElements<T: BitwiseCopyable>(count: Int) -> [T] {
        let byteCount = count * MemoryLayout<T>.stride
        let region = bytes.extracting(offset ..< offset + byteCount)
        offset += byteCount
        return copyElements(from: region, count: count)
    }

    private func require(_ byteCount: Int) throws {
        if offset + byteCount > bytes.byteCount { throw BinaryDecodeError.truncated }
    }
}

public extension BinaryDecoder where Storage == InMemory {
    /// Runs one decode traversal over `data` inside a single buffer access. Binary payloads are copied out, since
    /// nothing may outlive the access.
    static func decode<R>(_ data: Data, _ body: (inout BinaryDecoder<InMemory>) throws -> R) rethrows -> R {
        try data.withUnsafeBytes { raw in
            var decoder = BinaryDecoder(bytes: raw.bytes)
            return try body(&decoder)
        }
    }
}

public extension BinaryDecoder where Storage == Mapped {
    /// Runs one decode traversal over `blob`, handing `bulk(_:alignedTo:)` payloads back as zero-copy memory slices.
    /// The decoder's own lifetime is tied to `blob` by the compiler, while the blob owner can use the returned slices,
    /// which are plain offsets resolved against the same bytes.
    static func decode<R>(slicing blob: RawSpan, _ body: (inout BinaryDecoder<Mapped>) throws -> R) rethrows -> R {
        var decoder = BinaryDecoder(bytes: blob)
        return try body(&decoder)
    }
}
