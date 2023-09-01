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

import Foundation
import Dependencies

public struct ServerChangeAuthorizer {
    public var isServerChangeAvailable: () -> ServerChangeAvailability
}

extension ServerChangeAuthorizer: DependencyKey {
    public static var liveValue: Self = ServerChangeAuthorizer(
        isServerChangeAvailable: {
            @Dependency(\.credentialsProvider) var credentials
            @Dependency(\.featureFlagProvider) var featureFlags

            guard credentials.tier == CoreAppConstants.VpnTiers.free && featureFlags[\.showNewFreePlan] else {
                return .available
            }

            @Dependency(\.serverChangeStorage) var storage
            @Dependency(\.date) var date
            let now = date.now

            let skips = storage.connectionStack.filter { $0.intent == .random }

            guard let lastConnection = skips.first else {
                return .available
            }

            let reconnectDelay = TimeInterval(
                lastConnection.upsellNext ? storage.config.changeServerLongDelayInSeconds :
                    storage.config.changeServerShortDelayInSeconds
            )

            let connectionDate = lastConnection.date

            guard now.timeIntervalSince(connectionDate) > reconnectDelay else {
                return .unavailable(
                    until: connectionDate.addingTimeInterval(reconnectDelay),
                    duration: reconnectDelay,
                    exhaustedSkips: lastConnection.upsellNext
                )
            }

            return .available
        }
    )

    public enum ServerChangeAvailability: Equatable {
        case available
        case unavailable(until: Date, duration: TimeInterval, exhaustedSkips: Bool)
    }

    #if DEBUG
    public static let testValue: ServerChangeAuthorizer = liveValue
    #endif
}

extension DependencyValues {
    public var serverChangeAuthorizer: ServerChangeAuthorizer {
      get { self[ServerChangeAuthorizer.self] }
      set { self[ServerChangeAuthorizer.self] = newValue }
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
}
