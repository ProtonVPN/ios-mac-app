//
//  Created on 9/6/24.
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

import Foundation
import Dependencies
import Ergonomics
import NetShield

public struct NetShieldStatsProvider: TestDependencyKey {
    public var getStats: @Sendable () async -> NetShieldModel
    public var statsStream: @Sendable () -> AsyncStream<NetShieldModel>

    public static let testValue = NetShieldStatsProvider(
        getStats: { .init(trackersCount: 34, adsCount: 75, dataSaved: 2945, enabled: true) },
        statsStream: { .finished }
    )

}

extension DependencyValues {
    public var netShieldStatsProvider: NetShieldStatsProvider {
        get { self[NetShieldStatsProvider.self] }
        set { self[NetShieldStatsProvider.self] = newValue }
    }
}

extension NetShieldStatsProvider: DependencyKey {

    public static let liveValue: NetShieldStatsProvider = {
        let actor = NetShieldStatsProviderImplementation()

        return NetShieldStatsProvider(
            getStats: { actor.stats },
            statsStream: { NotificationCenter.default.notifications(NetShieldStatsNotification.self) }
        )
    }()
}

actor NetShieldStatsProviderImplementation {
    public var stats: NetShieldModel = .zero(enabled: false)

    public init() {
        Task {
            await startObserving()
        }
    }

    func startObserving() async {
        for await value in NotificationCenter.default.notifications(NetShieldStatsNotification.self) {
            self.stats = value
        }
    }
}
