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

import os.log

#if os(iOS) && DEBUG
    final class ProTUNAdapterStateDelegate: Sendable {
        let stream: AsyncStream<State>
        private let coordinator: StateCoordinator
        private let continuation: AsyncStream<State>.Continuation

        init() {
            let (stream, continuation) = AsyncStream<State>.makeStream()
            self.stream = stream
            self.continuation = continuation
            self.coordinator = StateCoordinator()
        }

        var state: State {
            get async throws {
                if let state = await coordinator.state {
                    return state
                }
                for await state in stream {
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

            Task {
                await coordinator.update(state)
            }
        }
    }

    extension ProTUNAdapterStateDelegate {
        private actor StateCoordinator {
            private(set) var state: State?

            init() {}

            func update(_ newState: State) {
                state = newState
            }
        }
    }
#endif
