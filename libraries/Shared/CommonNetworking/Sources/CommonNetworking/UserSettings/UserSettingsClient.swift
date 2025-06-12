//
//  Created on 14.02.2025 by John Biggs.
//
//  Copyright (c) 2025 Proton AG
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
import DependenciesMacros
import Domain

@DependencyClient
public struct UserSettingsClient: Sendable {
    public internal(set) var fetchUserSettings: @Sendable () async throws -> UserSettingsResponse
}

extension UserSettingsClient: DependencyKey {
    public static let liveValue: UserSettingsClient = {
        @Dependency(\.networking) var networking
        return UserSettingsClient(
            fetchUserSettings: {
                let request = UserSettingsRequest()
                return try await networking.perform(request: request)
            }
        )
    }()

    #if DEBUG
        public static let testValue: UserSettingsClient = UserSettingsClient {
            .init(code: 1000, userSettings: .init(password: .init(mode: .singlePassword), twoFactor: .init(type: .disabled)))
        }
    #endif
}

extension DependencyValues {
    public var userSettingsClient: UserSettingsClient {
        get { self[UserSettingsClient.self] }
        set { self[UserSettingsClient.self] = newValue }
    }
}
