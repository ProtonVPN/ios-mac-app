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
import Ergonomics

public enum ConnectionCommand: @unchecked Sendable {
    case connect(ConnectionSpec, ConnectionProtocol?, UserInitiatedVPNChange.VPNTrigger?)
    case disconnect(UserInitiatedVPNChange.VPNTrigger, completion: (@MainActor @Sendable () -> Void)? = nil)
    case retry
    case reconnect(ConnectionProtocol?)
    case applySettings(Set<ConnectionFeatureChange>)
    case clearConnectionData(completion: (@MainActor @Sendable () -> Void)? = nil)
}

@DependencyClient
public struct ConnectionCommandClient {
    public var send: @Sendable (_ command: ConnectionCommand) -> Void
    public var stream: @Sendable () async -> AsyncStream<ConnectionCommand> = { .finished }
}

extension ConnectionCommandClient: DependencyKey {
    public static let liveValue: ConnectionCommandClient = {
        let (stream, continuation) = AsyncStream<ConnectionCommand>.makeStream(bufferingPolicy: .bufferingNewest(1))

        let streamSource: StreamSource<ConnectionCommand>
        if #available(macOS 15, iOS 18.0, tvOS 18.0, *) {
            let shared = stream.share()
            streamSource = .asyncAlgorithms { shared.eraseToStream() }
        } else {
            streamSource = .sharedStream(stream.sharedStream)
        }
        return ConnectionCommandClient(
            send: { command in
                continuation.yield(command)
            },
            stream: {
                streamSource.newStream
            }
        )
    }()

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
