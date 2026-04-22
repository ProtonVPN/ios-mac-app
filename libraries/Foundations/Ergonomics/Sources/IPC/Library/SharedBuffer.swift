//
//  Created on 26/03/2026.
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

import Ergonomics
import Foundation
import IPCSeqlockHelpers

public extension IPCNotifications {
    struct SharedBuffer: ~Copyable {
        let rawBuffer: MmapBuffer
        let capacity: Int

        // Layout: seqlock (UInt64, 8 bytes) at offset 0 — managed by ipc_seqlock_* helpers
        //         length  (UInt32, 4 bytes) at offset 8 - the length of the data payload located next to the header
        public static let headerSize: Int = 12
        private static let lengthOffset: Int = 8

        public init(url: URL, capacity: Int = 65536) throws {
            self.capacity = capacity
            self.rawBuffer = try .init(path: url.path(), size: capacity + Self.headerSize)
        }
    }
}

public extension IPCNotifications.SharedBuffer {
    /// The number of completed writes, derived directly from the seqlock.
    var currentWriteCount: UInt64 {
        rawBuffer.withUnsafeMutableBytes { ipc_seqlock_read_begin($0) } / 2
    }
}

public extension IPCNotifications.SharedBuffer {
    /// Writes `data` under seqlock protection within the buffer.
    ///
    /// The seqlock ticks by 2 per write (odd while writing, even when idle), so
    /// write-count = seqlock / 2.
    /// - Parameter data: the `Data` payload you want to write.
    /// - Returns: the current write count of the buffer.
    borrowing func write(_ data: Data) throws -> UInt64 {
        rawBuffer.withUnsafeMutableBytes { ipc_seqlock_begin_write($0) }

        rawBuffer.storeBytes(of: UInt32(data.count), toByteOffset: Self.lengthOffset, as: UInt32.self)
        do {
            try rawBuffer.write(data: data, toByteOffset: Self.headerSize)
        } catch {
            // Restore seqlock to even so readers are not permanently blocked.
            rawBuffer.withUnsafeMutableBytes { ipc_seqlock_end_write($0) }
            throw error
        }

        rawBuffer.withUnsafeMutableBytes { ipc_seqlock_end_write($0) }
        return currentWriteCount
    }
}

public extension IPCNotifications.SharedBuffer {
    /// Reads a payload if the sequence numbers match.
    ///
    /// Goal is to detect if a concurrent write (by another thread or process) is happening while we're reading data.
    /// - Parameter expectedSequence: the expected sequence number.
    /// - Returns: a `Data` payload if the sequence numbers match, or `nil` otherwise.
    borrowing func read(expectedSequence: UInt64) -> Data? {
        let rawSeq = rawBuffer.withUnsafeMutableBytes {
            ipc_seqlock_read_begin($0)
        }
        guard rawSeq / 2 == expectedSequence else { return nil }

        let length = rawBuffer.load(fromByteOffset: Self.lengthOffset, as: UInt32.self)
        guard length > 0, length <= capacity else { return nil }

        let data = rawBuffer.read(fromByteOffset: Self.headerSize, count: Int(length))

        let seqMatch = rawBuffer.withUnsafeMutableBytes {
            ipc_seqlock_read_end($0, rawSeq)
        }
        guard seqMatch else { return nil }

        return data
    }
}
