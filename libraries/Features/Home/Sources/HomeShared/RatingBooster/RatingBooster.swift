//
//  Created on 2026-07-31 by Pawel Jurczyk.
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

import AsyncAlgorithms
import Combine
import Connection
import Dependencies
import DependenciesMacros
import Sharing

@DependencyClient
public struct RatingBooster {
    var connectionFailed: () -> Void
    var didConnect: () -> Void
    var didDisconnect: () -> Void
}

extension RatingBooster: DependencyKey {
    public static let testValue: RatingBooster = .init {} didConnect: {} didDisconnect: {}

    public static let liveValue: RatingBooster = {
        let ratingBooster = RatingBoosterImplementation()
        Task {
            @SharedReader(.connectionState) var connectionState
            let values = $connectionState.publisher.values
            for await (oldValue, newValue) in values.adjacentPairs() {
                if newValue.is(\.connected), !oldValue.is(\.connected) {
                    ratingBooster.didConnect()
                } else if newValue.is(\.disconnected), !oldValue.is(\.disconnected) {
                    ratingBooster.didDisconnect()
                }
            }
        }

        return RatingBooster(
            connectionFailed: ratingBooster.connectionFailed,
            didConnect: ratingBooster.didConnect,
            didDisconnect: ratingBooster.didDisconnect
        )
    }()
}

struct RatingBoosterImplementation {
    @Shared(.whenFirstSuccessfulConnectionStarted) var successfulTimestamp
    @Shared(.whenActiveConnectionStarted) var activeConnectionStartTimestamp
    @Shared(.successfulConnectionsInARow) var successfulConnectionsInARow
    @Shared(.successfulConnectionsSinceLastPrompt) var successfulConnectionsSinceLastPrompt

    @Dependency(\.date) var date

    func connectionFailed() {
        $activeConnectionStartTimestamp.withLock { $0 = nil }
        $successfulConnectionsInARow.withLock { $0 = 0 }
    }

    func didConnect() {
        if successfulTimestamp == nil {
            log.info("Saving first successful connection timestamp.")
            $successfulTimestamp.withLock { $0 = date.now }
        }

        if activeConnectionStartTimestamp == nil {
            $activeConnectionStartTimestamp.withLock { $0 = date.now }
            $successfulConnectionsSinceLastPrompt.withLock { $0 += 1 }
            $successfulConnectionsInARow.withLock { $0 += 1 }
        }
    }

    func didDisconnect() {
        $activeConnectionStartTimestamp.withLock { $0 = nil }
    }
}

public extension DependencyValues {
    var ratingBooster: RatingBooster {
        get { self[RatingBooster.self] }
        set { self[RatingBooster.self] = newValue }
    }
}
