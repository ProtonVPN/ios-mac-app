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
import Domain
import Foundation

enum SidebarConnectionCommand: @unchecked Sendable {
    case connect(ConnectionSpec, ConnectionProtocol?, UserInitiatedVPNChange.VPNTrigger?)
    case disconnect(UserInitiatedVPNChange.VPNTrigger, completion: (@MainActor @Sendable () -> Void)? = nil)
    case retry
    case reconnect(ConnectionProtocol?)
}

struct SidebarConnectionCommandClient {
    var send: @Sendable (_ command: SidebarConnectionCommand) -> Void
    var stream: @Sendable () async -> AsyncStream<SidebarConnectionCommand>
}

extension SidebarConnectionCommandClient: DependencyKey {
    private static let broadcaster = SidebarConnectionCommandBroadcaster()

    static let liveValue = SidebarConnectionCommandClient(
        send: { command in
            Task {
                await broadcaster.send(command)
            }
        },
        stream: {
            await broadcaster.stream()
        }
    )

    static let testValue = SidebarConnectionCommandClient(
        send: { _ in },
        stream: { .finished }
    )
}

extension DependencyValues {
    var sidebarConnectionCommandClient: SidebarConnectionCommandClient {
        get { self[SidebarConnectionCommandClient.self] }
        set { self[SidebarConnectionCommandClient.self] = newValue }
    }
}

private actor SidebarConnectionCommandBroadcaster {
    private var continuations: [UUID: AsyncStream<SidebarConnectionCommand>.Continuation] = [:]

    func send(_ command: SidebarConnectionCommand) {
        let activeContinuations = Array(continuations.values)
        for continuation in activeContinuations {
            continuation.yield(command)
        }
    }

    func stream() -> AsyncStream<SidebarConnectionCommand> {
        let id = UUID()
        let (stream, continuation) = AsyncStream.makeStream(of: SidebarConnectionCommand.self)
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
