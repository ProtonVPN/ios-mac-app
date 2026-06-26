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
        String(decoding: raw.prefix { $0 != 0 }, as: UTF8.self)
    }

    /// Checks the UTF8 grapheme cluster boundaries of the string before writing it.
    public static func write(_ string: String, into raw: UnsafeMutableRawBufferPointer) {
        // Pointer + bounds checks (also accounting for the NUL terminator)
        guard let base = raw.baseAddress, raw.count > 1 else {
            assertionFailure("Invalid buffer size for IPCFixedString")
            return
        }

        memset(base, 0, raw.count)

        // Reserve one byte for the NUL terminator.
        let maxBytes = raw.count - 1

        // Keep whole grapheme clusters while their UTF-8 still fits, so we never stop mid-cluster.
        var byteCount = 0
        let fitting = string.prefix { character in
            byteCount += character.utf8.count
            return byteCount <= maxBytes
        }
        raw.copyBytes(from: fitting.utf8)
    }
}
