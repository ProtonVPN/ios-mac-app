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

/// Type-safe role for a ``IPCNotifications/RawChannel``. The conforming struct decides how the channel accesses its
/// shared region, which in turn decides what it can do.
public protocol RawChannelRole {
    /// How a channel of this role holds its ``IPCNotifications/SharedRegion``.
    associatedtype RegionStore: Sendable

    /// For readers, just returns a buffer. Writers return a lock around the same type.
    static func makeStore(_ region: IPCNotifications.SharedRegion) -> RegionStore
}

public extension IPCNotifications {
    enum Reader: RawChannelRole {
        public static func makeStore(_ region: SharedRegion) -> SharedRegion {
            region
        }
    }

    enum Writer: RawChannelRole {
        public static func makeStore(_ region: SharedRegion) -> OSAllocatedUnfairLock<SharedRegion> {
            .init(initialState: region)
        }
    }
}

// MARK: - RawChannel

public extension IPCNotifications {
    /// A channel that maps a fixed-layout payload struct directly into shared memory,
    /// bypassing `Codable` serialisation entirely.
    ///
    /// The shared region is laid out as `[IPCSharedHeader][Payload]`, where `IPCSharedHeader` holds the atomic seqlock.
    /// `RawChannel` computes the exact payload offset using `MemoryLayout`, to detect updates through `notify_post`.
    ///
    /// The `Role` associated type ensures that an instance can be used for either reading or writing, but not both.
    ///
    /// - Warning: only one process may use a writeable channel for a region. This is a unidirectional primitive.
    final class RawChannel<Payload: BitwiseCopyable, Role: RawChannelRole>: Sendable {
        public let notification: Notification
        let payloadOffset: Int

        /// The shared region, stored as the `Role` dictates: a bare region for a ``Reader``, or a region behind an
        /// `OSAllocatedUnfairLock` for a ``Writer`` (where the lock both serialises in-process writers and *is* the
        /// thing held for each mutation's critical section).
        private let store: Role.RegionStore

        /// Byte offset of this channel's sub-region (its seqlock header) within the shared buffer.
        private let regionOffset: Int

        /// Absolute byte offset of this channel's payload within the shared buffer (sub-region header + alignment pad).
        var payloadBaseOffset: Int {
            regionOffset + payloadOffset
        }

        private static func computePayloadOffset() -> Int {
            let headerSize = MemoryLayout<IPCSharedHeader>.size
            let alignment = MemoryLayout<Payload>.alignment
            // Bit trick to round headerSize up to the next multiple of the `Payload` alignment.
            return (headerSize + alignment - 1) & ~(alignment - 1)
        }

        /// A view onto a sub-region of a shared buffer. Assumes a seqlock at `regionOffset`, followed by the payload.
        public init(notification: Notification, region: SharedRegion, regionOffset: Int) {
            self.payloadOffset = Self.computePayloadOffset()
            self.store = Role.makeStore(region)
            self.regionOffset = regionOffset
            self.notification = notification
        }

        public convenience init(notification: Notification, fileURL: URL) throws {
            let payloadOffset = Self.computePayloadOffset()
            let region = try SharedRegion(fileURL: fileURL, size: payloadOffset + MemoryLayout<Payload>.size)
            self.init(notification: notification, region: region, regionOffset: 0)
        }
    }
}

public extension IPCNotifications.RawChannel {
    struct SeqlockContention: Swift.Error {}

    /// Thrown when reading a region whose backing hasn't been attached yet (macOS).
    struct NotAttached: Swift.Error {}

    /// Default number of seqlock read attempts before giving up.
    static var defaultReadRetries: Int {
        20
    }
}

// MARK: - Writers

public extension IPCNotifications.RawChannel where Role == IPCNotifications.Writer {
    /// Mutates the payload in-place under seqlock protection, then notifies observers.
    /// - Parameter body: invoked while holding a lock, do not yield to any continuations within this closure.
    func mutate(_ body: (inout Payload) -> Void) {
        // Locking serialises in-process writers for this channel.
        store.withLock { region in
            region.withMutableSpan { span in
                Seqlock.performingWrite(to: &span, at: regionOffset) { span in
                    span.withUnsafeMutableBytes { raw in
                        let payload = raw.baseAddress!
                            .advanced(by: payloadBaseOffset)
                            .bindMemory(to: Payload.self, capacity: 1)
                        body(&payload.pointee)
                    }
                }
            }
        }
        IPCNotifications.signal(notification)
    }

    /// Takes the seqlock and clears the payload by storing its all-zeros value, then notifies the readers.
    func zero() {
        store.withLock { region in
            region.withMutableSpan { span in
                Seqlock.performingWrite(to: &span, at: regionOffset) { span in
                    span.storeBytes(
                        of: Ergonomics.zero(value: Payload.self),
                        toByteOffset: payloadBaseOffset,
                        as: Payload.self
                    )
                }
            }
        }
        IPCNotifications.signal(notification)
    }
}

// MARK: - Readers

public extension IPCNotifications.RawChannel where Role == IPCNotifications.Reader {
    /// Reads a consistent snapshot.
    /// - Parameter retries: the amount of retries if seqlock doesn't match.
    /// - Returns: A `Payload` value, or throws if it wasn't able to extract a value from the buffer.
    func read(retries: Int = defaultReadRetries) throws -> Payload {
        let (value, _) = try readField(at: payloadBaseOffset, of: Payload.self, retries: retries)
        guard let value else { throw SeqlockContention() }
        return value
    }

    /// Reads a value at an absolute offset within the shared buffer, using that channel's seqlock for consistency.
    ///
    /// If the value has not changed since `lastSequence`, the returned value will be `nil`. Otherwise, returns the
    /// updated value and the current sequence counter.
    private func readField<T: BitwiseCopyable>(
        at offset: Int,
        of _: T.Type,
        since lastSequence: UInt64 = ~0, // lets callers do a one-shot read without caring about the sequence number
        retries: Int = defaultReadRetries
    ) throws -> (value: T?, sequence: UInt64) {
        guard let attempt = store.withSpan({ span in
            Seqlock.tryingRead(from: span, at: regionOffset, since: lastSequence, retries: retries) { span in
                span.unsafeLoad(fromByteOffset: offset, as: T.self)
            }
        }) else {
            throw NotAttached()
        }
        guard let result = attempt else { throw SeqlockContention() }
        return result
    }
}

public extension IPCNotifications.RawChannel where Role == IPCNotifications.Reader {
    /// A stream of payloads emitted from the channel. See ``stream(reconcileOn:_:)`` for `reconcileOn`.
    func stream(reconcileOn resumeSignal: AsyncStream<Void> = .finished) -> AsyncStream<Payload> {
        stream(reconcileOn: resumeSignal) { $0 }
    }

    /// A stream of payloads transformed into a domain value `T`.
    /// - Parameters:
    ///   - reconcileOn: ticks (e.g. app resume) that re-check the channel for an update missed while suspended.
    ///   - transform: maps each payload to the value callers actually want.
    func stream<T: Sendable>(
        reconcileOn resumeSignal: AsyncStream<Void> = .finished,
        _ transform: @escaping @Sendable (Payload) -> T
    ) -> AsyncStream<T> {
        // Get updates to the Darwin notification here, and every time we get pinged check the seqlock to see if our
        // field has changed. `readField` can fail if the read is interrupted too many times, but this is unlikely
        // unless something in the extension is very wrong.
        let posts = IPCNotifications.streamRawState(notification)
        return AsyncStream { continuation in
            let task = Task { [self] in
                // `~0` is 0xFFFF... and matches no valid sequence, so the first `readField` should always work
                var lastSequence: UInt64 = ~0
                for await _ in merge(posts.map { _ in () }, resumeSignal) {
                    guard let (payload, sequence) = try? readField(
                        at: payloadBaseOffset,
                        of: Payload.self,
                        since: lastSequence
                    ) else { continue }
                    lastSequence = sequence
                    guard let payload else { continue }
                    continuation.yield(transform(payload))
                }
            }
            continuation.onTermination = { _ in task.cancel() }
        }
    }

    /// A stream of a single field's values. Gets broadcasted with every update of the payload.
    func stream<T: Sendable>(forField keyPath: KeyPath<Payload, T>) -> AsyncStream<T> {
        stream { $0[keyPath: keyPath] }
    }
}
