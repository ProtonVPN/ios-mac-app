//
//  Created on 23/04/2026 by Max Kupetskyi.
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
import DependenciesMacros
import Domain
import Foundation

public enum ConnectionCommand: @unchecked Sendable {
    case connect(ConnectionSpec, ConnectionProtocol?, UserInitiatedVPNChange.VPNTrigger?)
    case disconnect(UserInitiatedVPNChange.VPNTrigger, completion: (@MainActor @Sendable () -> Void)? = nil)
    case retry
    case reconnect(ConnectionProtocol?)
    case applySettings(Set<ConnectionFeatureChange.AgentFeature>)
    case clearConnectionData(completion: (@MainActor @Sendable () -> Void)? = nil)
}

@DependencyClient
public struct ConnectionCommandClient {
    public var send: @Sendable (_ command: ConnectionCommand) -> Void
    public var stream: @Sendable () async -> AsyncStream<ConnectionCommand> = { .finished }
}

extension ConnectionCommandClient: DependencyKey {
    private static let broadcaster = ConnectionCommandBroadcaster()

    public static let liveValue = ConnectionCommandClient(
        send: { command in
            Task {
                await broadcaster.send(command)
            }
        },
        stream: {
            await broadcaster.stream()
        }
    )

    public static let testValue = ConnectionCommandClient(
        send: { _ in },
        stream: { .finished }
    )
}

public extension DependencyValues {
    var connectionCommandClient: ConnectionCommandClient {
        get { self[ConnectionCommandClient.self] }
        set { self[ConnectionCommandClient.self] = newValue }
    }
}

private actor ConnectionCommandBroadcaster {
    private var continuations: [UUID: AsyncStream<ConnectionCommand>.Continuation] = [:]

    func send(_ command: ConnectionCommand) {
        let activeContinuations = Array(continuations.values)
        for continuation in activeContinuations {
            continuation.yield(command)
        }
    }

    func stream() -> AsyncStream<ConnectionCommand> {
        let id = UUID()
        let (stream, continuation) = AsyncStream.makeStream(of: ConnectionCommand.self)
        continuations[id] = continuation
        continuation.onTermination = { [weak self] _ in
            guard let self else { return }
            Task {
                await self.removeContinuation(id)
            }
        }
        return stream
    }

    private func removeContinuation(_ id: UUID) {
        continuations.removeValue(forKey: id)
    }
}
