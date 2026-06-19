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
import simd

/// Raised when a binary blob ends before the reader expected — a truncated/corrupt resource.
public enum BinaryDecodeError: Error {
    case truncated
}

// MARK: - Writer

/// Little-endian binary writer backing the globe codec: header + tightly packed POD arrays.
struct Writer {
    var data = Data()

    mutating func append(_ value: some Any) {
        withUnsafeBytes(of: value) { data.append(contentsOf: $0) }
    }

    /// Length-prefixed POD array: `UInt32` count followed by `count * stride` raw bytes.
    mutating func appendArray(_ array: [some Any]) {
        append(UInt32(array.count))
        array.withUnsafeBytes { data.append(contentsOf: $0) }
    }

    mutating func appendColor(_ color: SIMD4<Float>) {
        append(color)
    }

    mutating func appendRange(_ range: Range<Int>) {
        append(UInt32(range.lowerBound))
        append(UInt32(range.count))
    }

    mutating func appendString(_ string: String) {
        let bytes = Array(string.utf8)
        append(UInt16(bytes.count))
        data.append(contentsOf: bytes)
    }
}

// MARK: - Reader

/// Little-endian binary reader backing the globe codec.
struct Reader {
    let data: Data
    /// Byte offset into `data`'s contents, 0-based — matching the `withUnsafeBytes` buffer, whose
    /// index 0 is always `data`'s first byte regardless of the `Data`'s own `startIndex`.
    var offset: Int = 0

    init(_ data: Data) {
        self.data = data
    }

    mutating func read<T>() throws -> T {
        let stride = MemoryLayout<T>.stride
        try require(stride)
        let value = data.withUnsafeBytes { raw in
            raw.loadUnaligned(fromByteOffset: offset, as: T.self)
        }
        offset += stride
        return value
    }

    /// Bulk-reads a length-prefixed POD array via a single `memcpy`.
    mutating func readArray<T>() throws -> [T] {
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

    mutating func readColor() throws -> SIMD4<Float> {
        try read()
    }

    mutating func readRange() throws -> Range<Int> {
        let lower = try Int(read() as UInt32)
        let count = try Int(read() as UInt32)
        return lower ..< (lower + count)
    }

    mutating func readString() throws -> String {
        let length = try Int(read() as UInt16)
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
