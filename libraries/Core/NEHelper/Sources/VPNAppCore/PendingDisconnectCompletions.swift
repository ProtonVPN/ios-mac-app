//
//  Created on 22/05/2026 by Max Kupetskyi.
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

/// Queue of callbacks to invoke when the VPN finishes disconnecting.
///
/// `ConnectionCommand.disconnect` carries an optional completion closure. The closure must fire
/// *after* the connection has actually transitioned to `.disconnected`, not when the disconnect
/// command was dispatched. This actor decouples the closure's lifetime from the TCA effect that
/// processes the command, so the completion survives effect cancellation (e.g. when a later
/// disconnect command supersedes an earlier one with `cancelInFlight`).
///
/// Callers enqueue completions when the disconnect command is received; consumers drain the queue
/// when `ConnectionFeature` emits `.delegate(.disconnected)`.
public final actor PendingDisconnectCompletions: Sendable {
    private var queue: [@MainActor @Sendable () -> Void] = []

    public init() {}

    public func enqueue(_ completion: @escaping @MainActor @Sendable () -> Void) {
        queue.append(completion)
    }

    public func drainAndInvoke() async {
        let items = queue
        queue.removeAll()
        for completion in items {
            await MainActor.run { completion() }
        }
    }
}

extension PendingDisconnectCompletions: DependencyKey {
    public static let liveValue: PendingDisconnectCompletions = .init()
    public static let testValue: PendingDisconnectCompletions = .init()
}

public extension DependencyValues {
    var pendingDisconnectCompletions: PendingDisconnectCompletions {
        get { self[PendingDisconnectCompletions.self] }
        set { self[PendingDisconnectCompletions.self] = newValue }
    }
}
