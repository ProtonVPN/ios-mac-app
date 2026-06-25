//
//  Created on 25/06/2026.
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

import IPCSeqlockHelpers

/// Swift wrappers over the C seqlock primitives in `IPCSeqlockHelpers`, expressed as scoped operations on a span so
/// callers never juggle begin/end pairs or reach for `withUnsafe[Mutable]Bytes` themselves.
///
/// `offset` is the byte position of the sub-region's seqlock header (its `IPCSharedHeader`) within `span`; the pointer
/// the C primitives need is taken from the span and never escapes the wrapper.
enum Seqlock {
    /// The number of completed writes to the region at `offset` — the seqlock counter halved, since it bumps once when a
    /// write starts and once when it ends. Spins briefly if a write is in progress, so the count is never mid-write.
    static func generation(of span: borrowing RawSpan, at offset: Int) -> UInt64 {
        readBegin(span, at: offset) / 2
    }

    /// Runs `body` as a write to the region at `offset` under seqlock protection: marks the counter odd, lets `body`
    /// mutate the payload through the span, then marks it even again.
    static func performingWrite<Value>(
        to span: inout MutableRawSpan,
        at offset: Int,
        _ body: (inout MutableRawSpan) -> Value
    ) -> Value {
        span.withUnsafeMutableBytes { ipc_seqlock_begin_write($0.baseAddress!.advanced(by: offset)) }
        defer {
            span.withUnsafeMutableBytes { ipc_seqlock_end_write($0.baseAddress!.advanced(by: offset)) }
        }
        return body(&span)
    }

    /// Attempts a consistent snapshot of the region at `offset`, re-running `body` up to `retries` times if a write
    /// races the read. Returns `body`'s value once it reads cleanly, or `nil` if every attempt was torn.
    static func tryingRead<Value>(
        from span: borrowing RawSpan,
        at offset: Int,
        retries: Int,
        _ body: (borrowing RawSpan) -> Value
    ) -> Value? {
        for _ in 0 ..< retries {
            let sequence = readBegin(span, at: offset)
            let value = body(span)
            let consistent = span.withUnsafeBytes {
                ipc_seqlock_read_end($0.baseAddress!.advanced(by: offset), sequence)
            }
            if consistent {
                return value
            }
        }
        return nil
    }

    /// Spins until no write is in progress and returns the (even) counter. Shared by ``generation(of:at:)`` and the
    /// ``tryingRead(_:at:retries:_:)`` retry loop.
    private static func readBegin(_ span: borrowing RawSpan, at offset: Int) -> UInt64 {
        span.withUnsafeBytes { ipc_seqlock_read_begin($0.baseAddress!.advanced(by: offset)) }
    }
}
