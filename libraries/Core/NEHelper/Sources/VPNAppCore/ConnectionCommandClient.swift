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
import Ergonomics
import Foundation

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

    /// Connects to the user's saved Quick Connect profile, or to the fastest server when they have none.
    ///
    /// Resolving the profile needs the profile store, which still lives in LegacyCommon, so apps with profiles install
    /// this at their entry point:
    ///
    /// ```swift
    /// prepareDependencies {
    ///     $0.connectionCommandClient.quickConnect = QuickConnectIntent.connect
    /// }
    /// ```
    ///
    /// Fold the implementation into ``liveValue`` once profiles move out of LegacyCommon, and drop the install.
    public var quickConnect: @Sendable (_ trigger: UserInitiatedVPNChange.VPNTrigger) -> Void
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
            },
            quickConnect: { _ in
                log.assertionFailure("Quick Connect used before the app installed its implementation")
            }
        )
    }()

    public static let testValue = ConnectionCommandClient(
        send: { _ in },
        stream: { .finished },
        quickConnect: { _ in }
    )
}

public extension DependencyValues {
    var connectionCommandClient: ConnectionCommandClient {
        get { self[ConnectionCommandClient.self] }
        set { self[ConnectionCommandClient.self] = newValue }
    }
}
