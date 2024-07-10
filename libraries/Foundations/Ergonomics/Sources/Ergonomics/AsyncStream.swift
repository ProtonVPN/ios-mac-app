//
//  Created on 05/07/2024.
//
//  Copyright (c) 2024 Proton AG
//
//  ProtonVPN is free software: you can redistribute it and/or modify
//  it under the terms of the GNU General Public License as published by
//  the Free Software Foundation, either version 3 of the License, or
//  (at your option) any later version.
//
//  ProtonVPN is distributed in the hope that it will be useful,
//  but WITHOUT ANY WARRANTY; without even the implied warranty of
//  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
//  GNU General Public License for more details.
//
//  You should have received a copy of the GNU General Public License
//  along with ProtonVPN.  If not, see <https://www.gnu.org/licenses/>.

import class Foundation.NSLock

// MARK: - Convenience

// From pointfreeco/swift-concurrency-extras
extension AsyncStream {
    init<S: AsyncSequence>(_ sequence: S) where S.Element == Element {
        let lock = NSLock()
        var iterator: S.AsyncIterator?
        self.init {
            lock.withLock {
                if iterator == nil {
                    iterator = sequence.makeAsyncIterator()
                }
            }
            return try? await iterator?.next()
        }
    }
}

extension AsyncThrowingStream where Failure == Swift.Error {
    /// Produces an `AsyncThrowingStream` from an `AsyncSequence` by consuming the sequence till it
    /// terminates, rethrowing any failure.
    ///
    /// - Parameter sequence: An async sequence.
    public init<S: AsyncSequence>(_ sequence: S) where S.Element == Element {
        let lock = NSLock()
        var iterator: S.AsyncIterator?
        self.init {
            lock.withLock {
                if iterator == nil {
                    iterator = sequence.makeAsyncIterator()
                }
            }
            return try await iterator?.next()
        }
    }
}

// TODO: Generalize with AsyncSequence once they gain primary associated types and remove @_spi

#if swift(<6.0)
// MARK: - AsyncStream wrapper

/// An `AsyncStream` wrapper capable of knowing if it has been (or is still) consumed.
public final class AwareAsyncStream<Element> {
    @_spi(Internals)
    public let stream: AsyncStream<Element>

    public var hasBeenListened: Bool {
        return lock.withLock { _hasBeenListened }
    }

    private var _hasBeenListened: Bool = false

    private let lock: NSLock

    public init(_ stream: AsyncStream<Element>) {
        self._hasBeenListened = false
        self.stream = stream
        self.lock = NSLock()
    }

    public convenience init<S>(_ sequence: S) where S: AsyncSequence, S.Element == Element {
        self.init(AsyncStream(sequence))
    }
}

extension AwareAsyncStream: AsyncSequence {
    public struct AwareAsyncIterator: AsyncIteratorProtocol {
        var sourceIterator: AsyncStream<Element>.AsyncIterator

        public mutating func next() async -> Element? {
            return await sourceIterator.next()
        }
    }

    public func makeAsyncIterator() -> AwareAsyncIterator {
        lock.withLock {
            _hasBeenListened = true
        }
        return AwareAsyncIterator(sourceIterator: stream.makeAsyncIterator())
    }
}

extension AwareAsyncStream {
    public static func makeStream(
        of elementType: Element.Type = Element.self,
        bufferingPolicy limit: AsyncStream<Element>.Continuation.BufferingPolicy = .unbounded
    ) -> (awareStream: AwareAsyncStream<Element>, continuation: AsyncStream<Element>.Continuation) {
        var continuation: AsyncStream<Element>.Continuation!
        let stream = AsyncStream<Element>(bufferingPolicy: limit) { continuation = $0 }
        return (awareStream: AwareAsyncStream(stream), continuation: continuation!)
    }
}

// MARK: AsyncThrowingStream

/// An `AsyncThrowingStream` wrapper capable of knowing if it has been (or is still) consumed.
public final class AwareAsyncThrowingStream<Element, Failure> where Failure: Swift.Error {
    @_spi(Internals)
    public let stream: AsyncThrowingStream<Element, Failure>

    public var hasBeenListened: Bool {
        return lock.withLock { _hasBeenListened }
    }

    private var _hasBeenListened: Bool = false

    private let lock: NSLock

    public init(_ stream: AsyncThrowingStream<Element, Failure>) {
        self._hasBeenListened = false
        self.stream = stream
        self.lock = NSLock()
    }

    public convenience init<S>(_ sequence: S) where S: AsyncSequence, S.Element == Element, Failure == Swift.Error {
        self.init(AsyncThrowingStream(sequence))
    }
}

extension AwareAsyncThrowingStream: AsyncSequence {
    public struct AwareAsyncThrowingIterator: AsyncIteratorProtocol {
        var sourceIterator: AsyncThrowingStream<Element, Failure>.AsyncIterator

        public mutating func next() async throws -> Element? {
            return try await sourceIterator.next()
        }
    }

    public func makeAsyncIterator() -> AwareAsyncThrowingIterator {
        lock.withLock {
            _hasBeenListened = true
        }
        return AwareAsyncThrowingIterator(sourceIterator: stream.makeAsyncIterator())
    }
}

extension AwareAsyncThrowingStream {
    public static func makeStream(
        of elementType: Element.Type = Element.self,
        throwing failureType: Failure.Type = Failure.self,
        bufferingPolicy limit: AsyncThrowingStream<Element, Failure>.Continuation.BufferingPolicy = .unbounded
    ) -> (
        stream: AwareAsyncThrowingStream<Element, Failure>,
        continuation: AsyncThrowingStream<Element, Failure>.Continuation
    ) where Failure == Error {
        var continuation: AsyncThrowingStream<Element, Failure>.Continuation!
        let stream = AsyncThrowingStream<Element, Failure>(bufferingPolicy: limit) { continuation = $0 }
        return (stream: AwareAsyncThrowingStream(stream), continuation: continuation!)
    }
}
#endif
