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

/// Reads and writes `world-globe.bin`, the serialised `MapGlobeModel`: a magic-plus-version header
/// followed by the model's own `code(with:)` traversal, little-endian and packed, bulk-copied on decode.
/// The whole-model layout lives on `MapGlobeModel`'s `BinaryCodable` conformance. This only owns the
/// header and the version.
public enum MapGlobeCodec {
    static let magic: UInt32 = 0x474C_4F42 // "GLOB"
    /// Bump on any layout change, together with regenerating the checked-in bin.
    static let version: UInt32 = 1

    public enum DecodeError: Error, Equatable {
        case badMagic
        case unsupportedVersion(UInt32)
        /// Bytes remained after the model was fully read: a corrupt file or a desynced reader.
        case trailingData
    }

    public static func encode(_ model: MapGlobeModel) throws -> Data {
        var coder = BinaryEncoder()
        coder.append(magic)
        coder.append(version)
        var model = model
        try model.code(with: &coder)
        return coder.data
    }

    public static func decode(_ data: Data) throws -> MapGlobeModel {
        var coder = BinaryDecoder(data)
        guard try coder.read() as UInt32 == magic else { throw DecodeError.badMagic }
        let fileVersion = try coder.read() as UInt32
        guard fileVersion == version else { throw DecodeError.unsupportedVersion(fileVersion) }

        var model = MapGlobeModel()
        try model.code(with: &coder)
        // A decoder that reads less than the encoder wrote is the one drift the shared traversal can't
        // catch on its own. Requiring full consumption closes it, and rejects trailing garbage too.
        guard coder.isAtEnd else { throw DecodeError.trailingData }
        return model
    }
}
