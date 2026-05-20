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
    final class RawChannel<Payload: BitwiseCopyable> {
        public let notification: Notification
        let payloadOffset: Int
        private let buffer: MmapBuffer

        public init(notification: Notification, fileURL: URL) throws {
            let headerSize = MemoryLayout<IPCSharedHeader>.size
            let alignment = MemoryLayout<Payload>.alignment
            // Bit trick to round headerSize up to the next multiple of the `Payload` alignment.
            let payloadOffset = (headerSize + alignment - 1) & ~(alignment - 1)
            self.buffer = try .init(path: fileURL.path(), size: payloadOffset + MemoryLayout<Payload>.size)
            self.payloadOffset = payloadOffset
            self.notification = notification
        }
    }
}

// MARK: - Write

public extension IPCNotifications.RawChannel {
    /// Mutates the payload in-place under seqlock protection, then notify observers.
    /// - Parameter body: a closure with an instance you can modify.
    func mutate(_ body: (inout Payload) -> Void) {
        let offset = payloadOffset
        buffer.withUnsafeMutableBytes { base in
            ipc_seqlock_begin_write(base)
            body(&base.advanced(by: offset).assumingMemoryBound(to: Payload.self).pointee)
            ipc_seqlock_end_write(base)
        }
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
        let offset = payloadOffset + fieldOffset
        buffer.withUnsafeMutableBytes { base in
            ipc_seqlock_begin_write(base)
            base.advanced(by: offset).assumingMemoryBound(to: T.self).pointee = value
            ipc_seqlock_end_write(base)
        }
        // We leverage the UInt64 token to use the upper 4 bytes for the field offset,
        // and the remaining 4 bytes for the size of the field
        let sizeOfField = MemoryLayout<T>.size
        let payload = (UInt64(UInt32(bitPattern: Int32(fieldOffset))) << 32) | UInt64(UInt32(bitPattern: Int32(sizeOfField)))
        IPCNotifications.postRawState(notification, state: payload)
    }
}

// MARK: - Read

/// Reads a consistent snapshot.
/// - Parameter retries: the amount of retries if seqlock doesn't match.
/// - Returns: An optional `Payload` value, or `nil` if write contention prevented a clean read.

public extension IPCNotifications.RawChannel {
    struct SeqlockContention: Swift.Error {}

    func read(retries: Int = 20) throws -> Payload {
        let offset = payloadOffset
        return try buffer.withUnsafeMutableBytes { base in
            for _ in 0 ..< retries {
                let seq = ipc_seqlock_read_begin(base)
                let snapshot = base.advanced(by: offset).assumingMemoryBound(to: Payload.self).pointee
                if ipc_seqlock_read_end(base, seq) {
                    return snapshot
                }
            }
            throw SeqlockContention()
        }
    }

    private func readField<T>(at offset: Int, of _: T.Type, retries: Int = 20) throws -> T {
        try buffer.withUnsafeMutableBytes { base in
            for _ in 0 ..< retries {
                let seq = ipc_seqlock_read_begin(base)
                let value = base.advanced(by: offset).assumingMemoryBound(to: T.self).pointee
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
        IPCNotifications.observeRawState(notification, queue: queue) { _ in
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
            // We're extracting the field offset via the 4 upper bytes of the notify token
            let fieldOffset = Int(Int32(bitPattern: UInt32(payload >> 32)))
            guard MemoryLayout<Payload>.offset(of: keyPath) == fieldOffset else {
                onUnrelatedFieldChange?()
                return
            }
            let offset = self.payloadOffset + fieldOffset
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
