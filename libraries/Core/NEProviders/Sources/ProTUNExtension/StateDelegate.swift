//
//  Created on 18/02/2026 by Chris Janusiewicz.
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

import Dependencies
import Ergonomics
import os.log
import protun

final class ProTUNAdapterStateDelegate: Sendable {
    private enum StateDelegateError: Error {
        case streamTerminated
    }

    let stateSource: StreamSource<VpnState>

    var state: VpnState {
        get async throws {
            if let state = await coordinator.state {
                return state
            }
            for await state in stateSource.newStream {
                return state
            }
            throw StateDelegateError.streamTerminated
        }
    }

    /// The last state ProTUN reported, or nil if it has not reported anything yet
    var currentState: VpnState? {
        get async { await coordinator.state }
    }

    /// How long ``whenState(_:timeout:)`` waits for its condition before giving up.
    enum Timeout {
        case duration(Duration)
        case never
    }

    enum WaitError: Swift.Error {
        case timeout
        /// The state stream finished, or the waiting task was cancelled, before the condition held.
        case streamEnded
    }

    /// Resolves once `condition` holds, immediately when it already does.
    func whenState(
        _ condition: @escaping @Sendable (VpnState) -> Bool,
        timeout: Timeout
    ) async throws(WaitError) {
        let upcomingStates = stateSource.newStream
        if let current = await coordinator.state, condition(current) {
            return
        }

        enum Outcome {
            case matched
            case ended
            case timedOut
        }
        let outcome = await withTaskGroup(of: Outcome.self) { group in
            group.addTask {
                for await state in upcomingStates where condition(state) {
                    return .matched
                }
                return .ended
            }
            if case let .duration(limit) = timeout {
                group.addTask {
                    @Dependency(\.continuousClock) var clock
                    try? await clock.sleep(for: limit)
                    return Task.isCancelled ? .ended : .timedOut
                }
            }
            let first = await group.next() ?? .ended
            group.cancelAll()
            return first
        }

        switch outcome {
        case .matched: return
        case .timedOut: throw .timeout
        case .ended: throw .streamEnded
        }
    }

    private let coordinator: StateCoordinator
    private let continuation: AsyncStream<VpnState>.Continuation

    private let task: Task<Void, Never>

    init() {
        let (stream, continuation) = AsyncStream<VpnState>.makeStream()
        self.continuation = continuation
        self.stateSource = StreamSource.source(for: stream)
        self.coordinator = StateCoordinator()
        self.task = Task { [unowned coordinator, stateSource] in
            await coordinator.startListening(to: stateSource)
        }
    }

    deinit {
        task.cancel()
    }
}

extension ProTUNAdapterStateDelegate: StateChangedCallback {
    func onStateChanged(state: VpnState) {
        continuation.yield(state)
    }
}

extension ProTUNAdapterStateDelegate {
    private actor StateCoordinator {
        enum Error: Swift.Error {
            case listeningFailed
        }

        private(set) var state: VpnState? {
            didSet {
                let stateDescription = state?.description ?? "nil"
                Logger.adapter.info("Internal ProTUN state changed: \(stateDescription, privacy: .public)")
            }
        }

        func startListening(to stateSource: StreamSource<VpnState>) async {
            for await newState in stateSource.newStream {
                state = newState
            }
        }
    }
}
