//
//  Created on 20/06/2026.
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

/// Reads and writes `world-globe.bin`, the serialised `MapGlobeModel`. The whole-model layout lives on
/// `MapGlobeModel`'s `BinaryCodable` conformance. This only owns the header, the version, and the section alignment.
public enum MapGlobeCodec {
    static let magic: UInt32 = 0x1F30_DF00 // "🌍" + 0xF00
    /// Bump on any layout change, together with regenerating the checked-in bin.
    static let version: UInt32 = 1

    /// Alignment of the binary-array sections within the blob, and therefore within a page-aligned mapping of it: the
    /// strictest buffer-offset alignment any Metal device class requires, so a mapped section can be bound to the GPU
    /// by offset with no copy.
    public static let gpuSectionAlignment = 256

    public enum DecodeError: Error, Equatable {
        case badMagic
        case unsupportedVersion(UInt32)
        /// Bytes remained after the model was fully read: a corrupt file or a desynced reader.
        case trailingData
    }

    /// Note that `MapGlobeModel<Mapped>` has no encoding path since we only care about _reading_ that from memory.
    public static func encode(_ model: MapGlobeModel<InMemory>) throws -> Data {
        var coder = BinaryEncoder()
        coder.append(magic)
        coder.append(version)
        var model = model
        try model.code(with: &coder)
        return coder.data
    }

    public static func decode(_ data: Data) throws -> MapGlobeModel<InMemory> {
        try BinaryDecoder<InMemory>.decode(data) { coder in
            try decodeModel(with: &coder)
        }
    }

    /// Decodes an object in-place without copying the underlying data. The array sections come back as slices of
    /// `blob`, resolved against the same bytes at each later use, so whatever owns the blob's storage must outlive the
    /// returned model.
    public static func decode(slicing blob: RawSpan) throws -> MapGlobeModel<Mapped> {
        try BinaryDecoder<Mapped>.decode(slicing: blob) { coder in
            try decodeModel(with: &coder)
        }
    }

    private static func decodeModel<Storage: BinaryBacking>(with coder: inout BinaryDecoder<Storage>) throws -> MapGlobeModel<Storage> {
        guard try coder.read() as UInt32 == magic else { throw DecodeError.badMagic }
        let fileVersion = try coder.read() as UInt32
        guard fileVersion == version else { throw DecodeError.unsupportedVersion(fileVersion) }

        var model = MapGlobeModel<Storage>()
        try model.code(with: &coder)
        // A decoder that reads less than the encoder wrote is the one drift the shared traversal can't
        // catch on its own. Requiring full consumption closes it, and rejects trailing garbage too.
        guard coder.isAtEnd else { throw DecodeError.trailingData }
        return model
    }
}
