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

import Ergonomics
import Foundation
import IPCSeqlockHelpers
import os

// MARK: - RawChannel

public extension IPCNotifications {
    /// A channel that maps a fixed-layout payload struct directly into shared memory,
    /// bypassing `Codable` serialisation entirely.
    ///
    /// The mmap region is laid out as `[IPCSharedHeader][Payload]`, where
    /// `IPCSharedHeader` holds the `_Atomic uint64_t` seqlock at offset 0.
    /// `RawChannel` computes the exact payload offset using `MemoryLayout`, matching
    /// the C compiler's `offsetof(Region, payload)`.
    ///
    /// - ``mutate(_:)`` acquires the seqlock, hands a pointer to the payload to the
    ///   caller, then releases the seqlock and posts a Darwin notification.
    /// - ``read()`` takes a consistent snapshot of the payload via the seqlock read
    ///   protocol, retrying on write contention.
    final class RawChannel<Payload: BitwiseCopyable>: Sendable {
        public let notification: Notification
        let payloadOffset: Int
        private let region: SharedRegion
        /// Byte offset of this channel's sub-region (its seqlock header) within the shared buffer.
        private let regionOffset: Int

        /// Seqlock only protects cross-process readers from one writer. `writeLock` exists to make sure only one
        /// *in-process* writer is mutating the channel at any given time.
        private let writeLock = OSAllocatedUnfairLock()

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
            self.region = region
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

// MARK: - Write

public extension IPCNotifications.RawChannel {
    /// Mutates the payload in-place under seqlock protection, then notify observers.
    /// - Parameter body: a closure with an instance you can modify.
    func mutate(_ body: (inout Payload) -> Void) {
        writeLock.lock()
        region.withUnsafeMutableBytes { full in
            let base = full.advanced(by: regionOffset)
            ipc_seqlock_begin_write(base)
            body(&full.advanced(by: payloadBaseOffset).assumingMemoryBound(to: Payload.self).pointee)
            ipc_seqlock_end_write(base)
        }
        writeLock.unlock()
        IPCNotifications.post(notification)
    }

    struct FieldNotFound: Swift.Error {}

    /// Mutates a specific field of the payload under seqlock protection, then notify observers of the field that was modified.
    /// - Parameters:
    ///   - keyPath: a `KeyPath` of the field you want to modify.
    ///   - value: the new value you want to apply for the field.
    func mutate<T>(_ keyPath: KeyPath<Payload, T>, to value: T) throws {
        guard let fieldOffset = MemoryLayout<Payload>.offset(of: keyPath) else {
            throw FieldNotFound()
        }
        let offset = payloadBaseOffset + fieldOffset
        writeLock.lock()
        region.withUnsafeMutableBytes { full in
            let base = full.advanced(by: regionOffset)
            ipc_seqlock_begin_write(base)
            full.advanced(by: offset).assumingMemoryBound(to: T.self).pointee = value
            ipc_seqlock_end_write(base)
        }
        writeLock.unlock()
        // We leverage the UInt64 token to use the upper 4 bytes for the field offset,
        // and the remaining 4 bytes for the size of the field
        let sizeOfField = MemoryLayout<T>.size
        let payload = (UInt64(UInt32(bitPattern: Int32(fieldOffset))) << 32) | UInt64(UInt32(bitPattern: Int32(sizeOfField)))
        IPCNotifications.postRawState(notification, state: payload)
    }
}

// MARK: - Generation & teardown

public extension IPCNotifications.RawChannel {
    /// Uses the atomic seqlock as a generation counter, to detect any missed reads.
    var generation: UInt64 {
        region.withUnsafeMutableBytes { ipc_seqlock_read_begin($0.advanced(by: regionOffset)) } / 2
    }

    /// Takes the seqlock and zero-fills the payload. Does *not* send a notification.
    func zero() {
        let size = MemoryLayout<Payload>.size
        writeLock.lock()
        region.withUnsafeMutableBytes { full in
            let base = full.advanced(by: regionOffset)
            ipc_seqlock_begin_write(base)
            memset(full.advanced(by: payloadBaseOffset), 0, size)
            ipc_seqlock_end_write(base)
        }
        writeLock.unlock()
    }
}

// MARK: - Read

public extension IPCNotifications.RawChannel {
    struct SeqlockContention: Swift.Error {}

    /// Default number of seqlock read attempts before giving up.
    static var defaultReadRetries: Int {
        20
    }

    /// Reads a consistent snapshot.
    /// - Parameter retries: the amount of retries if seqlock doesn't match.
    /// - Returns: A `Payload` value, or throws if it wasn't able to extract a value from the buffer.
    func read(retries: Int = defaultReadRetries) throws -> Payload {
        try readField(at: payloadBaseOffset, of: Payload.self, retries: retries)
    }

    /// Reads a value at an absolute offset within the shared buffer, under that channel's seqlock.
    private func readField<T>(at offset: Int, of _: T.Type, retries: Int = defaultReadRetries) throws -> T {
        try region.withUnsafeMutableBytes { full in
            let base = full.advanced(by: regionOffset)
            for _ in 0 ..< retries {
                let seq = ipc_seqlock_read_begin(base)
                let value = full.advanced(by: offset).assumingMemoryBound(to: T.self).pointee
                if ipc_seqlock_read_end(base, seq) {
                    return value
                }
            }
            throw SeqlockContention()
        }
    }
}

// MARK: - Observe

public extension IPCNotifications.RawChannel {
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
        // Several channels can share one notification on a coalesced buffer, re-read only when our sub-region changed.
        let lastSeen = OSAllocatedUnfairLock<UInt64>(initialState: generation)
        return IPCNotifications.observeRawState(notification, queue: queue) { _ in
            let current = self.generation
            let advanced = lastSeen.withLock { seen -> Bool in
                guard current != seen else { return false }
                seen = current
                return true
            }
            guard advanced else { return }
            do {
                let value = try self.read()
                handler(.success(value))
            } catch {
                handler(.failure(error))
            }
        }
    }
}

public extension IPCNotifications.RawChannel {
    /// Observes a specific field updated via the channel, with handling happening on the main actor.
    @discardableResult
    func observeField<T>(
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
    func observeField<T>(
        _ keyPath: KeyPath<Payload, T>,
        on queue: DispatchQueue,
        handler: @escaping (Result<T, any Swift.Error>) -> Void,
        onUnrelatedFieldChange: (() -> Void)? = nil
    ) -> IPCNotifications.Token {
        IPCNotifications.observeRawState(notification, queue: queue) { payload in
            // The notify token packs the field offset in the upper 4 bytes and the field size in the lower 4.
            // Make sure that it matches the field that we're currently subscribed to.
            let fieldOffset = Int(Int32(bitPattern: UInt32(payload >> 32)))
            let fieldSize = Int(Int32(bitPattern: UInt32(payload & 0xFFFF_FFFF)))
            guard MemoryLayout<Payload>.offset(of: keyPath) == fieldOffset,
                  MemoryLayout<T>.size == fieldSize else {
                onUnrelatedFieldChange?()
                return
            }
            let offset = self.payloadBaseOffset + fieldOffset
            do {
                let value = try self.readField(at: offset, of: T.self)
                handler(.success(value))
            } catch {
                handler(.failure(error))
            }
        }
    }
}

public extension IPCNotifications.RawChannel {
    /// A stream of only success payloads emitted from the channel.
    /// - Returns: An `AsyncStream` of `Payload` values.
    func stream() -> AsyncStream<Payload> {
        AsyncStream { continuation in
            let token = observe { result in
                if let value = try? result.get() {
                    continuation.yield(value)
                }
            }
            let observation = token.observation()
            continuation.onTermination = { _ in observation.cancel() }
        }
    }

    /// A stream of success payloads transformed into a domain value `T`.
    /// - Returns: An `AsyncStream` of transformed values.
    func stream<T: Sendable>(_ transform: @escaping @Sendable (Payload) -> T) -> AsyncStream<T> {
        AsyncStream { continuation in
            let token = observe { result in
                if let value = try? result.get() {
                    continuation.yield(transform(value))
                }
            }
            let observation = token.observation()
            continuation.onTermination = { _ in observation.cancel() }
        }
    }

    /// A stream of fields updates of type `T` emitted from the channel.
    /// - Parameter keyPath: a `KeyPath` of the field of type `T` that was modified.
    /// - Returns: An `AsyncStream` of fields of type `T` values.
    func stream<T>(forField keyPath: KeyPath<Payload, T>) -> AsyncStream<T> {
        AsyncStream { continuation in
            let token = observeField(keyPath) { result in
                if let value = try? result.get() {
                    continuation.yield(value)
                }
            }
            let observation = token.observation()
            continuation.onTermination = { _ in observation.cancel() }
        }
    }
}
