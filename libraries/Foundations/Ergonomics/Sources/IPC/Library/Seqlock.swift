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

    /// Attempts to read from the given span, invoking `body` on the memory region up to `retries` times.
    ///
    /// If the value has not changed since `lastSequence`, the function will return `nil` for the value, with the
    /// current sequence number. If the value has changed, returns the new value and sequence number. If the region
    /// could not be read successfully due to contention, the function returns `nil`. For best results, make sure that
    /// `body` is only reading memory and performing simple operations as quickly as possible.
    static func tryingRead<Value>(
        from span: borrowing RawSpan,
        at offset: Int,
        since lastSequence: UInt64 = ~0,
        retries: Int,
        _ body: (borrowing RawSpan) -> Value
    ) -> (value: Value?, sequence: UInt64)? {
        for _ in 0 ..< retries {
            guard let sequence = readBegin(span, at: offset, since: lastSequence) else {
                return (nil, lastSequence)
            }

            let value = body(span)
            let consistent = span.withUnsafeBytes {
                ipc_seqlock_read_end($0.baseAddress!.advanced(by: offset), sequence)
            }

            if consistent {
                return (value, sequence)
            }
        }
        return nil
    }

    /// If the contents protected by the seqlock have changed since `lastSequence`, returns the new sequence number.
    /// Otherwise returns `nil`.
    private static func readBegin(
        _ span: borrowing RawSpan,
        at offset: Int,
        since lastSequence: UInt64
    ) -> UInt64? {
        assert(span.byteCount + MemoryLayout<UInt64>.size >= offset)

        var changed = false
        let sequence = span.withUnsafeBytes {
            ipc_seqlock_read_begin($0.baseAddress!.advanced(by: offset), lastSequence, &changed)
        }

        return changed ? sequence : nil
    }
}
