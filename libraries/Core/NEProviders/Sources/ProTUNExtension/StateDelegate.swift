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

#if os(iOS) && DEBUG
    import AsyncAlgorithms
    import Ergonomics
    import os.log

    final class ProTUNAdapterStateDelegate: Sendable {
        enum StateSource {
            typealias StreamFactory = @Sendable () -> AsyncStream<State>

            case sharedStream(SharedAsyncStream<State>) // our own backported SharedStream
            case asyncAlgorithms(StreamFactory) // the one from Apple swift-async-algorithms package
        }

        private enum StateDelegateError: Error {
            case streamTerminated
        }

        let stateSource: StateSource

        var state: State {
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

        private let coordinator: StateCoordinator
        private let continuation: AsyncStream<State>.Continuation

        private let task: Task<Void, Never>

        init() {
            let (stream, continuation) = AsyncStream<State>.makeStream()
            self.continuation = continuation
            self.coordinator = StateCoordinator()

            if #available(iOS 18.0, *) {
                let shared = stream.share()
                self.stateSource = .asyncAlgorithms { shared.eraseToStream() }
                self.task = Task { [unowned coordinator, stateSource] in
                    await coordinator.startListening(to: stateSource)
                }
            } else {
                self.stateSource = .sharedStream(stream.sharedStream)
                self.task = Task { [unowned coordinator, stateSource] in
                    await coordinator.startListening(to: stateSource)
                }
            }
        }

        deinit {
            task.cancel()
        }
    }

    extension ProTUNAdapterStateDelegate: StateChangedCallback {
        func onStateChanged(state: State) {
            continuation.yield(state)
        }
    }

    extension ProTUNAdapterStateDelegate {
        private actor StateCoordinator {
            enum Error: Swift.Error {
                case listeningFailed
            }

            private(set) var state: State? {
                didSet {
                    let stateDescription = state?.description ?? "nil"
                    Logger.adapter.info("Internal ProTUN state changed: \(stateDescription, privacy: .public)")
                }
            }

            func startListening(to stateSource: StateSource) async {
                for await newState in stateSource.newStream {
                    state = newState
                }
            }
        }
    }

    extension ProTUNAdapterStateDelegate.StateSource {
        var newStream: AsyncStream<State> {
            switch self {
            case let .sharedStream(sharedStream):
                sharedStream.subscribe()
            case let .asyncAlgorithms(factory):
                factory()
            }
        }
    }
#endif
