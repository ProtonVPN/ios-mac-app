//
//  Created on 07/09/2023.
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
import Domain
import Foundation
import Sharing

struct ServerChangeAuthorizerImplementation {
    func serverChangeAvailability() -> ServerChangeAuthorizer.ServerChangeAvailability {
        @Dependency(\.credentialsProvider) var credentials

        guard credentials.tier.isFree else {
            return .available
        }

        @Dependency(\.date) var date
        let now = date.now

        @SharedReader(.serverChangeConnectionStack) var connectionStack
        @SharedReader(.serverChangeConfig) var config

        let skips = (connectionStack ?? []).filter { $0.intent == .random }

        guard let lastConnection = skips.first else {
            return .available
        }

        let reconnectDelay = TimeInterval(
            lastConnection.upsellNext ? config.changeServerLongDelayInSeconds :
                config.changeServerShortDelayInSeconds
        )

        let connectionDate = lastConnection.date

        guard now.timeIntervalSince(connectionDate) >= reconnectDelay else {
            return .unavailable(
                until: connectionDate.addingTimeInterval(reconnectDelay),
                duration: reconnectDelay,
                exhaustedSkips: lastConnection.upsellNext
            )
        }

        return .available
    }

    func registerServerChange(connectedAt connectionDate: Date) {
        @SharedReader(.serverChangeConfig) var config
        @SharedReader(.serverChangeConnectionStack) var connectionStack

        let recentConnections = (connectionStack ?? [])
            .prefix(max(0, config.changeServerAttemptLimit - 1))
            .filter { $0.intent == .random }

        let recentlyUpsold = recentConnections.contains(where: \.upsellNext)

        let serverChangeItem = ConnectionStackItem(
            intent: .random,
            date: connectionDate,
            upsellNext: recentConnections.count >= (config.changeServerAttemptLimit - 1) &&
                !recentlyUpsold
        )

        log.debug("Registering server change", metadata: ["item": "\(serverChangeItem)"])
        pushServerChangeConnection(serverChangeItem)
    }
}
