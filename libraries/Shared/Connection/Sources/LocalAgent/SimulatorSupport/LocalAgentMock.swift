//
//  Created on 13/06/2024.
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

#if targetEnvironment(simulator)
import Foundation
import ConnectionFoundations
import Dependencies
@_spi(Internals) import Ergonomics
import XCTestDynamicOverlay

final class LocalAgentMock: LocalAgent {
    enum MockError: Swift.Error {
        case priorListeningIsMandatory
    }

    var state: LocalAgentState {
        get throws {
            // If this failure is triggered in tests, this mock was used before a reducer subscribed to receive
            // events through `eventStream`.
            guard eventAwareStream.hasBeenListened else {
                throw MockError.priorListeningIsMandatory
            }
            return _state
        }
    }

    private var _state: LocalAgentState

    func createEventStream() -> AsyncThrowingStream<LocalAgentEvent, Swift.Error> {
        let (awareStream, continuation) = AwareAsyncThrowingStream<LocalAgentEvent, Swift.Error>.makeStream()
        self.eventAwareStream = awareStream
        self.continuation = continuation
        return awareStream.stream
    }

    var connectionTask: Task<Void, Error>?
    var connectionDuration: Duration = .milliseconds(500)
    var connectionErrorToThrow: Error?
    var disconnectionTask: Task<Void, Error>?
    var disconnectionDuration: Duration = .milliseconds(250)

    private var eventAwareStream: AwareAsyncThrowingStream<LocalAgentEvent, Swift.Error>
    private var continuation: AsyncThrowingStream<LocalAgentEvent, Swift.Error>.Continuation

    init(
        state: LocalAgentState,
        connectionErrorToThrow: Error? = nil
    ) {
        self._state = state
        self.connectionErrorToThrow = connectionErrorToThrow

        let (stream, continuation) = AwareAsyncThrowingStream<LocalAgentEvent, Swift.Error>.makeStream()
        self.eventAwareStream = stream
        self.continuation = continuation
    }

    func connect(configuration: ConnectionConfiguration, data: VPNAuthenticationData) throws {
        disconnectionTask?.cancel()
        connectionTask = Task { [connectionErrorToThrow, continuation, connectionDuration] in
            @Dependency(\.continuousClock) var clock

            try await clock.sleep(for: connectionDuration)

            if let connectionErrorToThrow {
                throw connectionErrorToThrow
            }

            continuation.yield(.state(.connected))
        }
    }

    func disconnect() {
        disconnectionTask = Task { [continuation, disconnectionDuration] in
            @Dependency(\.continuousClock) var clock
            try await clock.sleep(for: disconnectionDuration)
            continuation.yield(.state(.disconnected))
        }
    }
}
#endif
