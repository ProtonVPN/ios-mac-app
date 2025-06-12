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

// This approach is broken because we're listening to the stream from two places
// Besides, the notification isn't even posted with Connection package
public struct NetShieldStatsProvider: TestDependencyKey, Sendable {
    public internal(set) var getStats: @Sendable () async -> NetShieldModel
    public internal(set) var statsStream: @Sendable () -> AsyncStream<NetShieldModel>

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

@available(macOS 12, *)
extension NetShieldStatsProvider: DependencyKey {
    public static let liveValue: NetShieldStatsProvider = {
        let actor = NetShieldStatsProviderImplementation()

        return NetShieldStatsProvider(
            getStats: { await actor.stats },
            statsStream: { NotificationCenter.default.notifications(NetShieldStatsNotification.self) }
        )
    }()
}

@available(macOS 12, *)
actor NetShieldStatsProviderImplementation {
    private(set) var stats: NetShieldModel = .zero(enabled: false)

    init() {
        Task { @MainActor in
            await startObserving()
        }
    }

    private func startObserving() async {
        for await value in NotificationCenter.default.notifications(NetShieldStatsNotification.self) {
            stats = value
        }
    }
}
