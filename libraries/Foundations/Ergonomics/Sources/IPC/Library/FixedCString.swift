//
//  Created on 17/06/2026.
//
//  Copyright (c) 2026 Proton AG
//
//  Proton VPN is free software: you can redistribute it and/or modify
//  it under the terms of the GNU General Public License as published by
//  the Free Software Foundation, either version 3 of the License, or
//  (at your option) any later version.
//
//  Proton VPN is distributed in the hope that it will be useful,
//  but WITHOUT ANY WARRANTY; without even the implied warranty of
//  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
//  GNU General Public License for more details.
//
//  You should have received a copy of the GNU General Public License
//  along with Proton VPN.  If not, see <https://www.gnu.org/licenses/>.

import Foundation

/// Marshaling for fixed-size `char[N]` fields in shared-memory payloads.
///
/// This code needs to be cautious because it's responsible for communicating the name of the user's ISP, which can
/// contain accents or other non-standard characters.
public enum IPCFixedString {
    public static func read(_ raw: UnsafeRawBufferPointer) -> String {
        let bytes = raw.prefix { $0 != 0 }
        return String(decoding: bytes, as: UTF8.self)
    }

    /// Go one character of the string at a time when writing to the pointer, taking care not to stop in the middle
    /// of any UTF-8 grapheme clusters.
    public static func write(_ string: String, into raw: UnsafeMutableRawBufferPointer) {
        guard let base = raw.baseAddress, !raw.isEmpty else { return }
        memset(base, 0, raw.count)

        // Reserve one byte for \0.
        let maxBytes = raw.count - 1
        guard maxBytes > 0 else { return }

        var offset = 0
        for character in string {
            let utf8 = character.utf8
            guard offset + utf8.count <= maxBytes else { break }
            for byte in utf8 {
                raw[offset] = byte
                offset += 1
            }
        }
    }
}
