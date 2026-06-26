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
@testable import IPCErgonomics
import Testing

/// Probably overkill, but just in case
struct FixedCStringTests {
    private func roundTrip(_ string: String, capacity: Int) -> (decoded: String, bytes: [UInt8]) {
        var buffer = [UInt8](repeating: 0xFF, count: capacity)
        buffer.withUnsafeMutableBytes { IPCFixedString.write(string, into: $0) }
        let decoded = buffer.withUnsafeBytes { IPCFixedString.read($0) }
        return (decoded, buffer)
    }

    @Test
    func asciiRoundTrips() {
        let (decoded, bytes) = roundTrip("peer-42", capacity: 64)
        #expect(decoded == "peer-42")
        #expect(bytes[7] == 0) // NUL after the 7 written bytes
    }

    @Test
    func multibyteRoundTripsWhenItFits() {
        // "héllo" is 6 UTF-8 bytes; fits in 8 (7 usable + NUL).
        let (decoded, _) = roundTrip("héllo", capacity: 8)
        #expect(decoded == "héllo")
    }

    @Test
    func truncatesOnCharacterBoundaryNeverSplittingAScalar() {
        // Each "é" is 2 bytes. Capacity 4 → 3 usable → only one "é" fits; the rest is dropped whole.
        let (decoded, bytes) = roundTrip("ééé", capacity: 4)
        #expect(decoded == "é")
        #expect(bytes[2] == 0) // reserved NUL untouched
        // The decoded value must be valid UTF-8 with no partial scalar.
        #expect(Array(decoded.utf8) == [0xC3, 0xA9])
    }

    @Test
    func dropsAGraphemeThatCannotFitRatherThanSplittingIt() {
        // "👍" is 4 bytes. Capacity 4 → 3 usable → can't fit → empty, not a broken half-emoji.
        let (decoded, _) = roundTrip("👍", capacity: 4)
        #expect(decoded == "")
        // With capacity 5 (4 usable) it fits exactly.
        let (decodedFits, _) = roundTrip("👍", capacity: 5)
        #expect(decodedFits == "👍")
    }

    @Test
    func emptyStringZeroFillsTheField() {
        let (decoded, bytes) = roundTrip("", capacity: 4)
        #expect(decoded == "")
        #expect(bytes.allSatisfy { $0 == 0 })
    }

    @Test
    func exactFitLeavesRoomForNul() {
        // 3 ASCII bytes into a 4-byte field: fills 0..<3, byte 3 is the NUL.
        let (decoded, bytes) = roundTrip("abc", capacity: 4)
        #expect(decoded == "abc")
        #expect(bytes == [0x61, 0x62, 0x63, 0x00])
    }
}
