//
//  Created on 31/08/2023.
//
//  Copyright (c) 2023 Proton AG
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

import Dependencies
import Foundation
import VPNAppCore

extension ServerChangeAuthorizer: @retroactive DependencyKey {
    public static var liveValue: ServerChangeAuthorizer = {
        let authorizer = ServerChangeAuthorizerImplementation()
        let cache = ServerChangeAvailabilityCache()
        return ServerChangeAuthorizer(
            serverChangeAvailability: {
                @Dependency(\.date) var date
                if let cached = cache.value(asOf: date.now) {
                    return cached
                }
                let fresh = authorizer.serverChangeAvailability()
                cache.store(fresh)
                return fresh
            },
            registerServerChangeAtDate: { connectionDate in
                authorizer.registerServerChange(connectedAt: connectionDate)
                // A successful server change shifts the cooldown window — drop the cache so
                // the next read recomputes from `serverChangeStorage`.
                cache.invalidate()
            }
        )
    }()
}

/// Process-wide cache for the most recent `ServerChangeAvailability` so that the StatusMenu,
/// Header, SidebarFeature, and ConnectionStatusBannerFeature consumers don't each separately
/// reach into `serverChangeStorage` on every read. Develop previously cached this per
/// view-model; with multiple consumers reading the same persisted state, a single cache at
/// the dependency layer is cheaper and avoids per-consumer drift.
private final class ServerChangeAvailabilityCache: @unchecked Sendable {
    private let lock = NSLock()
    private var cached: ServerChangeAuthorizer.ServerChangeAvailability?

    /// Returns the cached value only if it's still an active `.unavailable` cooldown at
    /// `now`. `.available` or expired-cooldown caches return nil so the caller recomputes.
    func value(asOf now: Date) -> ServerChangeAuthorizer.ServerChangeAvailability? {
        lock.lock()
        defer { lock.unlock() }
        guard case let .unavailable(until, _, _) = cached, until > now else {
            return nil
        }
        return cached
    }

    func store(_ value: ServerChangeAuthorizer.ServerChangeAvailability) {
        lock.lock()
        cached = value
        lock.unlock()
    }

    func invalidate() {
        lock.lock()
        cached = nil
        lock.unlock()
    }
}

public enum ServerChangeViewState {
    case available
    case unavailable(duration: String)

    public static func from(state: ServerChangeAuthorizer.ServerChangeAvailability) -> Self {
        switch state {
        case .available:
            return .available

        case let .unavailable(until, _, _):
            @Dependency(\.date) var date
            let formattedDuration = until.timeIntervalSince(date.now)
                .asColonSeparatedString(maxUnit: .hour, minUnit: .minute)
            return .unavailable(duration: formattedDuration)
        }
    }

    /// Little helper to use more elegant code
    public var isUnavailable: Bool {
        switch self {
        case .unavailable:
            true
        default:
            false
        }
    }
}
