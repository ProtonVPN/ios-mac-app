//
//  Created on 30/05/2024.
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

import CommonNetworking
import ComposableArchitecture
import Dependencies
import DependenciesMacros
import Domain
import Ergonomics
import Foundation
import Persistence
import SwiftUI

@DependencyClient
struct LogicalsRefresher {
    var refreshLogicals: () async throws -> Void
    var shouldRefreshLogicals: () -> Bool = { false }
}

struct LogicalsRefresherProvider {
    @Shared(.lastLogicalsRefresh) private var lastLogicalsRefresh: TimeInterval = 0
    @SharedReader(.userLocation) var userLocation: StoredUserLocation?

    var liveValue: LogicalsRefresher {
        .init(
            refreshLogicals: refreshLogicals,
            shouldRefreshLogicals: shouldRefreshLogicals
        )
    }

    func refreshLogicals() async throws {
        @Dependency(\.userLocationService) var userLocationService
        try? await userLocationService.updateUserLocation()

        @Dependency(\.logicalsClient) var client
        @Dependency(\.appLanguage) var appLanguage
        let requestLanguage = appLanguage()
        let location = userLocation?.location
        let truncatedIp = (location?.ip).flatMap { TruncatedIp(ip: $0) }
        let logicalsResponse = try await client.fetchLogicals(ip: truncatedIp, countryCode: location?.country)

        @Dependency(\.serverRepository) var repository
        repository.upsert(servers: logicalsResponse)
        // A full fetch refreshes every stored translation, so record the language the payload arrived in.
        repository.setMetadata(requestLanguage, for: .translationsLanguage)

        let now = Dependency(\.date).wrappedValue.now
        $lastLogicalsRefresh.withLock { $0 = now.timeIntervalSince1970 }
    }

    func shouldRefreshLogicals() -> Bool {
        let now = Dependency(\.date).wrappedValue.now
        let refreshInterval = Constants.Time.fullServerRefresh
        if now.timeIntervalSince1970 - lastLogicalsRefresh > refreshInterval {
            return true
        }
        @Dependency(\.serverRepository) var repository
        if repository.isEmpty {
            return true
        }
        // The stored translations arrived in the language of the fetch that stored them. A language
        // change makes them stale, so refresh early instead of waiting out the interval.
        @Dependency(\.appLanguage) var appLanguage
        if repository.getMetadata(.translationsLanguage) != appLanguage() {
            return true
        }
        return false
    }
}

extension LogicalsRefresher: DependencyKey {
    static let liveValue: LogicalsRefresher = LogicalsRefresherProvider().liveValue
    static let previewValue: LogicalsRefresher = .init(refreshLogicals: {}, shouldRefreshLogicals: { false })
}

extension DependencyValues {
    var logicalsRefresher: LogicalsRefresher {
        get { self[LogicalsRefresher.self] }
        set { self[LogicalsRefresher.self] = newValue }
    }
}
