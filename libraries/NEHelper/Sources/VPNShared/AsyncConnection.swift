//
//  Created on 07/07/2025 by Shahin Katebi.
//
//  Copyright (c) 2025 Proton AG
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

import Foundation
import Network

/// Async wrapper around NWConnection
public final class AsyncConnection: Sendable {
    private let connection: NWConnection
    private let stateStream: AsyncStream<NWConnection.State>
    private let stateContinuation: AsyncStream<NWConnection.State>.Continuation

    public var isCancelled: Bool {
        connection.state == .cancelled
    }

    public var interface: NWInterface? {
        connection.parameters.requiredInterface
    }

    public init(to endpoint: NWEndpoint, using parameters: NWParameters) {
        self.connection = NWConnection(to: endpoint, using: parameters)

        let (stream, continuation) = AsyncStream<NWConnection.State>.makeStream()
        self.stateStream = stream
        self.stateContinuation = continuation

        connection.stateUpdateHandler = { [weak self] state in
            self?.stateContinuation.yield(state)
        }
    }

    public var states: AsyncStream<NWConnection.State> {
        stateStream
    }

    public var nwEndpoint: NWEndpoint {
        connection.endpoint
    }

    public func start(queue: DispatchQueue) {
        connection.start(queue: queue)
    }

    public func send(content: Data, completion: @escaping @Sendable (NWError?) -> Void) {
        connection.send(content: content, completion: .contentProcessed(completion))
    }

    public func receive(
        minimumIncompleteLength: Int,
        maximumLength: Int,
        completion: @Sendable @escaping (Data?, NWConnection.ContentContext?, Bool, NWError?) -> Void
    ) {
        connection.receive(minimumIncompleteLength: minimumIncompleteLength, maximumLength: maximumLength, completion: completion)
    }

    /// Async wrapper around `receiveMessage` for UDP connections.
    public func receiveMessageAsync() async throws -> (Data?, Bool) {
        try await withCheckedThrowingContinuation { continuation in
            connection.receiveMessage { data, _, isComplete, error in
                if let error {
                    continuation.resume(throwing: error)
                } else {
                    continuation.resume(returning: (data, isComplete))
                }
            }
        }
    }

    public func cancel() {
        connection.stateUpdateHandler = nil
        connection.cancel()
        stateContinuation.finish()
    }

    deinit {
        if !isCancelled {
            cancel()
        }
    }
}
