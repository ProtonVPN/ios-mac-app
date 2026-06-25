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
import os

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

        /// The notify token we should expect to receive when getting updates to this region of the payload.
        var channelToken: UInt64 {
            (UInt64(UInt32(payloadBaseOffset)) << 32) | UInt64(UInt32(MemoryLayout<Payload>.size))
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
    struct FieldNotFound: Swift.Error {}
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
                    var payload = span.unsafeLoad(fromByteOffset: payloadBaseOffset, as: Payload.self)
                    body(&payload)
                    span.storeBytes(of: payload, toByteOffset: payloadBaseOffset, as: Payload.self)
                }
            }
        }
        IPCNotifications.postRawState(notification, state: channelToken)
    }

    /// Mutates a specific field of the payload under seqlock protection, then notify observers of the field that was modified.
    /// - Parameters:
    ///   - keyPath: a `KeyPath` of the field you want to modify.
    ///   - value: the new value you want to apply for the field.
    func mutate<T: BitwiseCopyable>(_ keyPath: KeyPath<Payload, T>, to value: T) throws {
        guard let fieldOffset = MemoryLayout<Payload>.offset(of: keyPath) else {
            throw FieldNotFound()
        }
        let offset = payloadBaseOffset + fieldOffset
        store.withLock { region in
            region.withMutableSpan { span in
                Seqlock.performingWrite(to: &span, at: regionOffset) { span in
                    span.storeBytes(of: value, toByteOffset: offset, as: T.self)
                }
            }
        }
        IPCNotifications.postRawState(notification, state: channelToken)
    }

    /// Takes the seqlock and clears the payload by storing its all-zeros value. Does *not* send a notification.
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
    }
}

// MARK: - Readers

public extension IPCNotifications.RawChannel where Role == IPCNotifications.Reader {
    /// Uses the atomic seqlock as a generation counter, to detect any missed reads.
    var generation: UInt64 {
        store.withSpan { span in
            Seqlock.generation(of: span, at: regionOffset)
        } ?? 0
    }

    /// Reads a consistent snapshot.
    /// - Parameter retries: the amount of retries if seqlock doesn't match.
    /// - Returns: A `Payload` value, or throws if it wasn't able to extract a value from the buffer.
    func read(retries: Int = defaultReadRetries) throws -> Payload {
        try readField(at: payloadBaseOffset, of: Payload.self, retries: retries)
    }

    /// Reads a value at an absolute offset within the shared buffer, under that channel's seqlock.
    private func readField<T: BitwiseCopyable>(at offset: Int, of _: T.Type, retries: Int = defaultReadRetries) throws -> T {
        let value = try store.withSpan { span -> T in
            guard let value = Seqlock.tryingRead(from: span, at: regionOffset, retries: retries, { span in
                span.unsafeLoad(fromByteOffset: offset, as: T.self)
            }) else {
                throw SeqlockContention()
            }
            return value
        }
        guard let value else { throw NotAttached() }
        return value
    }
}

public extension IPCNotifications.RawChannel where Role == IPCNotifications.Reader {
    /// Observes any payload posted to the channel on the main actor.
    @discardableResult
    func observe(
        handler: @MainActor @escaping (Result<Payload, any Swift.Error>) -> Void
    ) -> IPCNotifications.Token {
        observe(on: .main) { result in
            MainActor.assumeIsolated { handler(result) }
        }
    }

    /// Observes any payload posted to the channel on a specific `DispatchQueue`.
    @discardableResult
    func observe(
        on queue: DispatchQueue,
        handler: @escaping (Result<Payload, any Swift.Error>) -> Void
    ) -> IPCNotifications.Token {
        // Demux notifications according to the posted token, which uses the payload's offset and size in the region.
        let myToken = channelToken
        return IPCNotifications.observeRawState(notification, queue: queue) { token in
            guard token == myToken else { return }
            do {
                let value = try self.read()
                handler(.success(value))
            } catch {
                handler(.failure(error))
            }
        }
    }

    /// Observes a specific field updated via the channel, with handling happening on the main actor.
    @discardableResult
    func observeField<T: BitwiseCopyable>(
        _ keyPath: KeyPath<Payload, T>,
        handler: @MainActor @escaping (Result<T, any Swift.Error>) -> Void,
        onUnrelatedFieldChange: (() -> Void)? = nil
    ) -> IPCNotifications.Token {
        observeField(keyPath, on: .main) { result in
            MainActor.assumeIsolated { handler(result) }
        } onUnrelatedFieldChange: {
            onUnrelatedFieldChange?()
        }
    }

    /// Observes a specific field updated via the channel, with handling happening on a specific `DispatchQueue`.
    @discardableResult
    func observeField<T: BitwiseCopyable>(
        _ keyPath: KeyPath<Payload, T>,
        on queue: DispatchQueue,
        handler: @escaping (Result<T, any Swift.Error>) -> Void,
        onUnrelatedFieldChange: (() -> Void)? = nil
    ) -> IPCNotifications.Token {
        // React only to our own region's token.
        let myToken = channelToken
        let fieldOffset = MemoryLayout<Payload>.offset(of: keyPath)
        return IPCNotifications.observeRawState(notification, queue: queue) { token in
            guard token == myToken else {
                onUnrelatedFieldChange?()
                return
            }
            guard let fieldOffset else { return }
            do {
                let value = try self.readField(at: self.payloadBaseOffset + fieldOffset, of: T.self)
                handler(.success(value))
            } catch {
                handler(.failure(error))
            }
        }
    }
}

public extension IPCNotifications.RawChannel where Role == IPCNotifications.Reader {
    /// A stream of payloads emitted from the channel. See ``stream(reconcileOn:_:)`` for `reconcileOn`.
    func stream(reconcileOn resumeSignal: AsyncStream<Void> = .finished) -> AsyncStream<Payload> {
        stream(reconcileOn: resumeSignal) { $0 }
    }

    /// A stream of payloads transformed into a domain value `T`.
    /// - Parameters:
    ///   - reconcileOn: ticks (e.g. app resume) that force a refresh of the channel's generation counter.
    ///   - transform: maps each payload to the value callers actually want.
    func stream<T: Sendable>(
        reconcileOn resumeSignal: AsyncStream<Void> = .finished,
        _ transform: @escaping @Sendable (Payload) -> T
    ) -> AsyncStream<T> {
        let myToken = channelToken
        // Read from the channel whenever we get a notification with our token or a tick.
        // If the generation counter hasn't changed since the previous value, don't broadcast the change.
        let values = merge(
            IPCNotifications.streamRawState(notification).filter { $0 == myToken }.map { _ in () },
            resumeSignal
        )
        .compactMap { [self] _ in (try? read()).map { (generation, transform($0)) } }
        .removeDuplicates { $0.0 == $1.0 }
        .map(\.1)

        return AsyncStream { continuation in
            let task = Task {
                for await value in values {
                    continuation.yield(value)
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
