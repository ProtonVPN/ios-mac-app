//
//  Created on 03/04/2026.
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

import AsyncAlgorithms
import ConcurrencyExtras
import Ergonomics
import Foundation
import IPCSeqlockHelpers
import struct os.OSAllocatedUnfairLock

// MARK: - Channel roles

/// Marker roles for a ``IPCNotifications/RawChannel``. They carry no storage; they only gate, at compile time, whether
/// an instance exposes the reading or the writing API.
public enum ReaderRole {}
public enum WriterRole {}

// MARK: - RawChannel

public extension IPCNotifications {
    /// A channel that maps a fixed-layout payload struct directly into shared memory,
    /// bypassing `Codable` serialisation entirely.
    ///
    /// The window is laid out as `[IPCSharedHeader][Payload]`, where `IPCSharedHeader` holds the atomic seqlock.
    /// `RawChannel` computes the exact payload offset using `MemoryLayout`, and detects updates through `notify_post`.
    ///
    /// `Role` gates reading vs. writing; `Backing` selects the shared-memory transport and is specialized away by the
    /// compiler (no dynamic dispatch on the read/write path).
    ///
    /// - Warning: only one process may use a writeable channel for a window. This is a unidirectional primitive.
    struct RawChannel<Payload: BitwiseCopyable, Role, Backing: RegionBacking & ~Copyable>: ~Copyable, Sendable {
        public let notification: Notification

        /// The shared mapping this channel reads/writes. A reference, so several sibling channels view one mapping.
        let region: SharedRegion<Backing>

        /// Byte offset of this channel's window (its seqlock header) within the shared mapping.
        let regionOffset: Int

        /// Offset of the payload *within* the window, past the seqlock header and alignment padding.
        let payloadOffset: Int

        /// Absolute byte offset of this channel's payload within the shared mapping.
        var payloadBaseOffset: Int {
            regionOffset + payloadOffset
        }

        private static func computePayloadOffset() -> Int {
            let headerSize = MemoryLayout<IPCSharedHeader>.size
            let alignment = MemoryLayout<Payload>.alignment
            // Bit trick to round headerSize up to the next multiple of the `Payload` alignment.
            return (headerSize + alignment - 1) & ~(alignment - 1)
        }

        /// Manage the seqlock window carried by `seqlockRegion`. Consuming it transfers the sole right to read/write
        /// that window into this channel.
        public init(notification: Notification, seqlockRegion: consuming SeqlockRegion<Backing>) {
            self.notification = notification
            self.region = seqlockRegion.region
            self.regionOffset = seqlockRegion.regionOffset
            self.payloadOffset = Self.computePayloadOffset()
        }
    }
}

public extension IPCNotifications.RawChannel where Backing == FileBackedRegion {
    /// Standalone convenience: create and own a file mapping sized for a single window, and manage that one window.
    init(notification: IPCNotifications.Notification, fileURL: URL) throws {
        let payloadOffset = Self.computePayloadOffset()
        let size = payloadOffset + MemoryLayout<Payload>.size
        let region = try IPCNotifications.SharedRegion(FileBackedRegion(fileURL: fileURL, size: size))
        self.init(notification: notification, seqlockRegion: region.seqlockRegion(at: 0, length: size))
    }
}

public extension IPCNotifications.RawChannel where Backing: ~Copyable {
    struct SeqlockContention: Swift.Error {}

    /// Default number of seqlock read attempts before giving up.
    static var defaultReadRetries: Int {
        20
    }
}

// MARK: - Writers

public extension IPCNotifications.RawChannel where Role == WriterRole, Backing: ~Copyable {
    /// Mutates the payload in-place under seqlock protection, then notifies observers.
    /// - Parameter body: invoked while writing the window, do not yield to any continuations within this closure.
    func mutate(_ body: (inout Payload) -> Void) {
        region.withMutableRawSpan { span in
            Seqlock.performingWrite(to: &span, at: regionOffset) { span in
                span.withUnsafeMutableBytes { raw in
                    let payload = raw.baseAddress!
                        .advanced(by: payloadBaseOffset)
                        .bindMemory(to: Payload.self, capacity: 1)
                    body(&payload.pointee)
                }
            }
        }
        IPCNotifications.signal(notification)
    }

    /// Takes the seqlock and clears the payload by storing its all-zeros value, then notifies the readers.
    func zero() {
        region.withMutableRawSpan { span in
            Seqlock.performingWrite(to: &span, at: regionOffset) { span in
                span.storeBytes(
                    of: Ergonomics.zero(value: Payload.self),
                    toByteOffset: payloadBaseOffset,
                    as: Payload.self
                )
            }
        }
        IPCNotifications.signal(notification)
    }
}

// MARK: - Readers

public extension IPCNotifications.RawChannel where Role == ReaderRole, Backing: ~Copyable {
    /// Reads a consistent snapshot.
    /// - Parameter retries: the amount of retries if seqlock doesn't match.
    /// - Returns: A `Payload` value, or throws if it wasn't able to extract a value from the buffer.
    func read(retries: Int = defaultReadRetries) throws -> Payload {
        let (value, _) = try readField(at: payloadBaseOffset, of: Payload.self, retries: retries)
        guard let value else { throw SeqlockContention() }
        return value
    }

    /// Reads a value at an absolute offset within the shared mapping, using this window's seqlock for consistency.
    ///
    /// If the value has not changed since `lastSequence`, the returned value will be `nil`. Otherwise, returns the
    /// updated value and the current sequence counter.
    private func readField<T: BitwiseCopyable>(
        at offset: Int,
        of _: T.Type,
        since lastSequence: UInt64 = ~0, // lets callers do a one-shot read without caring about the sequence number
        retries: Int = defaultReadRetries
    ) throws -> (value: T?, sequence: UInt64) {
        let attempt = region.withRawSpan { span in
            Seqlock.tryingRead(from: span, at: regionOffset, since: lastSequence, retries: retries) { span in
                span.unsafeLoadUnaligned(fromByteOffset: offset, as: T.self)
            }
        }
        guard let result = attempt else { throw SeqlockContention() }
        return result
    }

    /// Attempts a non-blocking read of the payload if it has changed since `lastSequence`.
    ///
    /// - Parameter lastSequence: The sequence number from the previous successful read. Pass `~0` (all bits set)
    ///   to force reading the current value regardless of whether it changed.
    /// - Returns:
    ///   - `(value, sequence)` if the payload has been updated since `lastSequence` and the read succeeded.
    ///   - `nil` if:
    ///     - The payload hasn't changed since `lastSequence`, OR
    ///     - A writer collision occurred during the read (the seqlock detected concurrent writes).
    ///
    /// This is a non-throwing alternative to ``read(retries:)`` designed for polling loops. On `nil`, simply retry
    /// on the next iteration; do not treat it as an error.
    ///
    /// Prefer ``stream(reconcileOn:_:)`` unless you're implementing a custom event loop.
    func readIfChanged(since lastSequence: UInt64) -> (value: Payload?, sequence: UInt64)? {
        region.withRawSpan { span in
            Seqlock.tryingRead(from: span, at: regionOffset, since: lastSequence, retries: Self.defaultReadRetries) { span in
                span.unsafeLoadUnaligned(fromByteOffset: payloadBaseOffset, as: Payload.self)
            }
        }
    }
}

public extension IPCNotifications.RawChannel where Role == ReaderRole, Backing: ~Copyable {
    /// A stream of payloads emitted from the channel. See ``stream(reconcileOn:_:)`` for `reconcileOn`.
    func stream(reconcileOn reconcileSignals: AsyncStream<Void>...) -> AsyncStream<Payload> {
        stream(reconcileOn: reconcileSignals) { $0 }
    }

    /// A stream of payloads transformed into a domain value `T`.
    /// - Parameters:
    ///   - reconcileOn: zero or more extra tick sources (e.g. app-resume, surface-attach) that re-check
    ///     the channel for an update missed while the darwin notification wasn't observed. Merged with the
    ///     channel's own darwin notification internally; callers pass signals directly without pre-merging.
    ///   - transform: maps each payload to the value callers actually want.
    func stream<T: Sendable>(
        reconcileOn reconcileSignals: AsyncStream<Void>...,
        transform: sending @escaping (Payload) -> T
    ) -> AsyncStream<T> {
        stream(reconcileOn: reconcileSignals, transform)
    }

    /// A stream of a single field's values. Gets broadcasted with every update of the payload.
    func stream<T: Sendable>(forField keyPath: KeyPath<Payload, T>) -> AsyncStream<T> {
        stream { $0[keyPath: keyPath] }
    }
}

// MARK: - Stream internals

public extension IPCNotifications.RawChannel where Role == ReaderRole, Backing: ~Copyable {
    /// Variadic entry points forward here with `reconcileSignals` already collected into a collection,
    /// sidestepping Swift's restriction on forwarding variadic parameters to another variadic function.
    /// Public so wrappers in other modules (e.g. the typed channel accessors) can forward their own
    /// variadic `reconcileOn` here without hitting that same restriction.
    func stream<T: Sendable>(
        reconcileOn reconcileSignals: some Collection<AsyncStream<Void>>,
        _ transform: sending @escaping (Payload) -> T
    ) -> AsyncStream<T> {
        let posts = IPCNotifications.streamRawState(notification)
        let region = region
        let regionOffset = regionOffset
        let payloadBaseOffset = payloadBaseOffset

        // Fold all reconcile signals into one merged tick source alongside the channel's darwin notification.
        // Each `eraseToStream()` wraps the merge in a task that propagates cancellation outward.
        let ticks: AsyncStream<Void> = reconcileSignals.reduce(posts.map { _ in () }.eraseToStream()) {
            merge($0, $1).eraseToStream()
        }

        return UncheckedSendable(
            ticks
                .reductions(into: (sequence: UInt64.max, payload: Payload?.none)) { acc, _ in
                    acc.payload = nil
                    let read = region.withRawSpan { span in
                        Seqlock.tryingRead(from: span, at: regionOffset, since: acc.sequence, retries: Self.defaultReadRetries) { span in
                            span.unsafeLoadUnaligned(fromByteOffset: payloadBaseOffset, as: Payload.self)
                        }
                    }
                    guard let (newPayload, newSequence) = read else { return }
                    acc.sequence = newSequence
                    acc.payload = newPayload
                }
                .compactMap(\.payload)
                .map(transform)
        ).eraseToStream()
    }
}
