//
//  Created on 27/05/2026 by Max Kupetskyi.
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
import Foundation

/// Channel for surfacing "the authenticated session has changed" events from non-TCA layers
/// (NetworkingDelegate implementations on iOS/macOS/tvOS) to the TCA `ConnectionFeature`.
///
/// Triggers a partial logout in the connection layer — the tunnel is cleaned up and certs/keys
/// are cleared, while observation remains active. Replaces the broader `ConnectionBridge`,
/// which only ever carried this single event in practice.
public struct SessionChangeNotifier: Sendable {
    public var notify: @Sendable () async -> Void
    public var stream: @Sendable () -> AsyncStream<Void>

    public init(
        notify: @escaping @Sendable () async -> Void,
        stream: @escaping @Sendable () -> AsyncStream<Void>
    ) {
        self.notify = notify
        self.stream = stream
    }
}

public extension DependencyValues {
    var sessionChangeNotifier: SessionChangeNotifier {
        get { self[SessionChangeNotifier.self] }
        set { self[SessionChangeNotifier.self] = newValue }
    }
}

extension SessionChangeNotifier: DependencyKey {
    public static let liveValue: SessionChangeNotifier = {
        let broadcaster = SessionChangeBroadcaster()
        return SessionChangeNotifier(
            notify: { await broadcaster.notify() },
            stream: {
                AsyncStream { continuation in
                    let id = UUID()
                    Task { await broadcaster.register(id: id, continuation: continuation) }
                    continuation.onTermination = { @Sendable _ in
                        Task { await broadcaster.unregister(id: id) }
                    }
                }
            }
        )
    }()

    public static let testValue: SessionChangeNotifier = liveValue
}

private actor SessionChangeBroadcaster {
    private var continuations: [UUID: AsyncStream<Void>.Continuation] = [:]

    func notify() {
        for continuation in continuations.values {
            continuation.yield(())
        }
    }

    func register(id: UUID, continuation: AsyncStream<Void>.Continuation) {
        continuations[id] = continuation
    }

    func unregister(id: UUID) {
        continuations[id] = nil
    }
}
