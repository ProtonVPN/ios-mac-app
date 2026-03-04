//
//  Created on 20/02/2026 by adam.
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
import Foundation

@available(iOS, deprecated: 18, renamed: "AsyncShareSequence")
public final class SharedAsyncStream<Element: Sendable>: Sendable {
    private let base: SharedAsyncThrowingStream<Element>

    init<S: AsyncSequence>(_ sequence: S) where S.Element == Element {
        self.base = SharedAsyncThrowingStream(sequence)
    }

    public func subscribe() -> AsyncStream<Element> {
        let upstream = base.subscribe()
        return AsyncStream { continuation in
            Task {
                do {
                    for try await element in upstream {
                        continuation.yield(element)
                    }
                } catch {}
                continuation.finish()
            }
        }
    }
}

@available(iOS, deprecated: 18, renamed: "AsyncShareSequence")
public final class SharedAsyncThrowingStream<Element: Sendable>: Sendable {
    private struct State {
        var continuations: [UUID: AsyncThrowingStream<Element, any Error>.Continuation] = [:]
        var isFinished = false
    }

    private let state = ManagedCriticalState(State())
    private nonisolated(unsafe) var task: Task<Void, Never>!

    init<S: AsyncSequence>(_ base: S) where S.Element == Element {
        self.task = Task {
            do {
                for try await element in base {
                    self.broadcast(element)
                }
                self.finish()
            } catch {
                self.finish(throwing: error)
            }
        }
    }

    deinit {
        self.task.cancel()
    }

    private func broadcast(_ element: Element) {
        state.withCriticalRegion { state in
            for continuation in state.continuations.values {
                continuation.yield(element)
            }
        }
    }

    private func finish(throwing error: (any Error)? = nil) {
        state.withCriticalRegion { state in
            state.isFinished = true
            state.continuations.values.forEach { $0.finish(throwing: error) }
            state.continuations.removeAll()
        }
    }
}

public extension SharedAsyncThrowingStream {
    func subscribe() -> AsyncThrowingStream<Element, any Error> {
        AsyncThrowingStream { continuation in
            let id = UUID()
            let alreadyFinished = state.withCriticalRegion { state -> Bool in
                if state.isFinished { return true }
                state.continuations[id] = continuation
                return false
            }
            if alreadyFinished {
                continuation.finish()
                return
            }
            continuation.onTermination = { [weak self] _ in
                _ = self?.state.withCriticalRegion { $0.continuations.removeValue(forKey: id) }
            }
        }
    }
}

public extension AsyncSequence where Self: Sendable, Element: Sendable {
    @available(iOS, introduced: 17, obsoleted: 18, message: "Use .shared() from swift-async-algorithms on iOS 18+")
    var sharedStream: SharedAsyncStream<Element> {
        SharedAsyncStream(self)
    }
}

public extension AsyncSequence where Self: Sendable, Element: Sendable {
    @available(iOS, introduced: 17, obsoleted: 18, message: "Use .shared() from swift-async-algorithms on iOS 18+")
    var sharedThrowingStream: SharedAsyncThrowingStream<Element> {
        SharedAsyncThrowingStream(self)
    }
}

private final class ManagedCriticalState<State>: @unchecked Sendable {
    private var _state: State
    private let lock = NSLock()

    init(_ state: State) {
        self._state = state
    }

    func withCriticalRegion<R>(_ body: (inout State) throws -> R) rethrows -> R {
        try lock.withLock {
            try body(&_state)
        }
    }
}
