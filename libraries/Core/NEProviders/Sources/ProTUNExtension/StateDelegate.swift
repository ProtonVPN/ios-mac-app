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
            case sharedStream(SharedAsyncStream<State>)
            case rawStream(AsyncStream<State>)
        }

        let stateSource: StateSource

        private let coordinator: StateCoordinator
        private let continuation: AsyncStream<State>.Continuation

        init() {
            let (stream, continuation) = AsyncStream<State>.makeStream()
            self.continuation = continuation
            self.coordinator = StateCoordinator()

            if #available(iOS 18.0, *) {
                self.stateSource = .sharedStream(stream.sharedStream)
                Task {
                    try await self.coordinator.startListening(to: stateSource)
                }
            } else {
                self.stateSource = .rawStream(stream)
                Task {
                    try await self.coordinator.startListening(to: stateSource)
                }
            }
        }

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

        enum StateDelegateError: Error {
            case streamTerminated
        }
    }

    extension ProTUNAdapterStateDelegate: StateChangedCallback {
        func onStateChanged(state: State) {
            Logger.adapter.info("Internal ProTUN state changed: \(state, privacy: .public)")
            continuation.yield(state)
        }
    }

    extension ProTUNAdapterStateDelegate {
        private actor StateCoordinator {
            enum Error: Swift.Error {
                case listeningFailed
            }

            private(set) var state: State?

            func startListening(to stateSource: ProTUNAdapterStateDelegate.StateSource) async throws {
                let newStream = stateSource.newStream
                for await newState in newStream {
                    state = newState
                }
            }
        }
    }

    extension ProTUNAdapterStateDelegate.StateSource {
        var newStream: AsyncStream<State> {
            switch self {
            case let .sharedStream(sharedStream):
                return sharedStream.subscribe()
            case let .rawStream(asyncStream):
                if #available(iOS 18.0, *) {
                    return asyncStream.share().eraseToStream()
                } else {
                    assertionFailure("You shouldn't use a rawStream on pre iOS 18")
                    return asyncStream
                }
            }
        }
    }
#endif
