//
//  Created on 05/09/2024.
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

import Dependencies
import Foundation

public struct ServerChangeAuthorizer {
    public private(set) var serverChangeAvailability: () -> ServerChangeAvailability
    private var registerServerChangeAtDate: (Date) -> Void

    public func registerServerChange(connectedAt connectionDate: Date) {
        registerServerChangeAtDate(connectionDate)
    }

    public enum ServerChangeAvailability: Equatable {
        case available
        case unavailable(until: Date, duration: TimeInterval, exhaustedSkips: Bool)
    }

    public init(serverChangeAvailability: @escaping () -> ServerChangeAvailability, registerServerChangeAtDate: @escaping (Date) -> Void) {
        self.serverChangeAvailability = serverChangeAvailability
        self.registerServerChangeAtDate = registerServerChangeAtDate
    }
}

public extension DependencyValues {
    var serverChangeAuthorizer: ServerChangeAuthorizer {
        get { self[ServerChangeAuthorizer.self] }
        set { self[ServerChangeAuthorizer.self] = newValue }
    }
}

extension ServerChangeAuthorizer: DependencyKey {
    /// Builds an authorizer that answers from ``ServerChangeAuthorizerImplementation``, memoizing
    /// active cooldowns in a fresh ``ServerChangeAvailabilityCache``.
    ///
    /// ``liveValue`` holds a single instance so all consumers share one cache. Tests build their
    /// own instance per case, because a cached cooldown would otherwise outlive the case that
    /// produced it and be served to the next one.
    static func makeLive() -> ServerChangeAuthorizer {
        let authorizer = ServerChangeAuthorizerImplementation()
        let cache = ServerChangeAvailabilityCache()
        return ServerChangeAuthorizer(
            serverChangeAvailability: {
                // Tier is checked *before* the cache: the rate limit only exists for free user
                @Dependency(\.credentialsProvider) var credentials
                guard credentials.tier.isFree else {
                    return .available
                }
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
    }

    public static let liveValue: ServerChangeAuthorizer = makeLive()

    public static let testValue = ServerChangeAuthorizer {
        .unavailable(until: .distantFuture, duration: .infinity, exhaustedSkips: true)
    } registerServerChangeAtDate: { _ in
    }

    public static let previewValue = ServerChangeAuthorizer {
        .unavailable(
            until: Date().addingTimeInterval(60 * 60),
            duration: 60 * 60 * 2,
            exhaustedSkips: true
        )
    } registerServerChangeAtDate: { _ in
    }

    public static let availableValue = ServerChangeAuthorizer {
        .available
    } registerServerChangeAtDate: { _ in
    }
}
