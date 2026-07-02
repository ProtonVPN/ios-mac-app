//
//  Created on 02/07/2026 by Max Kupetskyi.
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

import Domain
import Foundation
import Sharing
import VPNAppCore

/// A single recorded server-change event, used to rate-limit free-tier "change server".
/// Migrated off `ServerChangeStorage.ConnectionStackItem`.
public struct ConnectionStackItem: Codable, Equatable, @unchecked Sendable {
    public let intent: ConnectionRequestType
    public let date: Date
    public let upsellNext: Bool

    public init(intent: ConnectionRequestType, date: Date, upsellNext: Bool) {
        self.intent = intent
        self.date = date
        self.upsellNext = upsellNext
    }
}

public extension SharedKey where Self == UserScopedAppStorageKey<[ConnectionStackItem]?> {
    /// The recent server-change events for the current user. Legacy key:
    /// `ServerChangeConnectionStack<username>` (JSON).
    static var serverChangeConnectionStack: Self {
        .json("ServerChangeConnectionStack")
    }
}

/// The maximum number of server-change events retained. Matches the legacy
/// `ServerChangeStorage.maximumStackCount`.
public let serverChangeMaximumStackCount = 64

/// Prepends a server-change event to the current user's stack, capping it at
/// ``serverChangeMaximumStackCount``. Replaces `ServerChangeStorage.push(item:)`.
public func pushServerChangeConnection(_ item: ConnectionStackItem) {
    @Shared(.serverChangeConnectionStack) var stack
    $stack.withLock { current in
        var copy = current ?? []
        copy.insert(item, at: 0)
        while copy.count > serverChangeMaximumStackCount {
            copy.removeLast()
        }
        current = copy
    }
}
