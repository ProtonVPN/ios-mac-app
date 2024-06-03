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

/// Use `refreshLogicalsIfNeeded()` to refresh logicals, but not more often than
/// predefined in `Constants.Time.fullServerRefresh`.
public class LogicalsRefresher {

    var refreshInterval = Constants.Time.fullServerRefresh
    @AppStorage("lastLogicalsRefresh") private var lastLogicalsRefresh: TimeInterval = 0

    public func refreshLogicalsIfNeeded() async throws {
        guard shouldRefreshLogicals() else { return }

        @Dependency(\.userLocationService) var userLocationService
        let location = try? await userLocationService.getUserLocation()

        @Dependency(\.logicalsClient) var client
        let logicalsResponse = try await client.fetchLogicals(TruncatedIp(ip: location?.ip))

        @Dependency(\.serverRepository) var repository
        repository.upsert(servers: logicalsResponse)

        let now = Dependency(\.date).wrappedValue.now
        lastLogicalsRefresh = now.timeIntervalSince1970
    }

    public func shouldRefreshLogicals() -> Bool {
        let now = Dependency(\.date).wrappedValue.now
        if now.timeIntervalSince1970 - lastLogicalsRefresh < refreshInterval {
            return false
        }
        return true
    }
}

extension LogicalsRefresher: DependencyKey {
    public static var liveValue: LogicalsRefresher = LogicalsRefresher()
}

extension DependencyValues {
    public var logicalsRefresher: LogicalsRefresher {
      get { self[LogicalsRefresher.self] }
      set { self[LogicalsRefresher.self] = newValue }
    }
}
