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

import Foundation
import Dependencies
import Domain
import Ergonomics
import SwiftUI
import ComposableArchitecture
import XCTestDynamicOverlay

public struct LogicalsRefresher {
    public var refreshLogicals: () async throws -> Void
    public var shouldRefreshLogicals: () -> Bool

    public init(refreshLogicals: @escaping () async throws -> Void = unimplemented(),
         shouldRefreshLogicals: @escaping () -> Bool = unimplemented()) {
        self.refreshLogicals = refreshLogicals
        self.shouldRefreshLogicals = shouldRefreshLogicals
    }
}

public struct LogicalsRefresherProvider {

    @Shared(.lastLogicalsRefresh) private var lastLogicalsRefresh: TimeInterval = 0
    @Shared(.userLocation) var userLocation: UserLocation?

    var liveValue: LogicalsRefresher {
        .init(refreshLogicals: refreshLogicals,
              shouldRefreshLogicals: shouldRefreshLogicals)
    }

    public func refreshLogicals() async throws {
        @Dependency(\.userLocationService) var userLocationService
        try? await userLocationService.updateUserLocation()

        @Dependency(\.logicalsClient) var client
        let truncatedIp = (userLocation?.ip).flatMap { TruncatedIp(ip: $0) }
        let logicalsResponse = try await client.fetchLogicals(truncatedIp)

        @Dependency(\.serverRepository) var repository
        repository.upsert(servers: logicalsResponse)

        let now = Dependency(\.date).wrappedValue.now
        lastLogicalsRefresh = now.timeIntervalSince1970
    }

    public func shouldRefreshLogicals() -> Bool {
        let now = Dependency(\.date).wrappedValue.now
        let refreshInterval = Constants.Time.fullServerRefresh
        if now.timeIntervalSince1970 - lastLogicalsRefresh > refreshInterval {
            return true
        }
        @Dependency(\.serverRepository) var repository
        if repository.isEmpty {
            return true
        }
        return false
    }
}

extension LogicalsRefresher: DependencyKey {
    public static let liveValue: LogicalsRefresher = LogicalsRefresherProvider().liveValue
}

extension DependencyValues {
    public var logicalsRefresher: LogicalsRefresher {
      get { self[LogicalsRefresher.self] }
      set { self[LogicalsRefresher.self] = newValue }
    }
}
