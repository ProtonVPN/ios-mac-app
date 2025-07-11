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

import Dependencies
import DependenciesMacros
import Domain
import Foundation
import ProtonCoreAuthentication
import ProtonCoreNetworking
import ProtonCoreServices
import VPNShared

@DependencyClient
public struct UserSettingsClient: Sendable {
    /// AuthCredentials need to be sent due to fetchUserSettings at login not having the most up-to-date credentials. Specially
    /// for credential-less, where the `isCredentialLess` is still false.
    public internal(set) var fetchUserSettings: @Sendable (_ authCredentials: AuthCredentials?) async throws -> UserSettings
}

extension UserSettingsClient: DependencyKey {
    public static let liveValue: UserSettingsClient = {
        @Dependency(\.networking) var networking
        return UserSettingsClient(
            fetchUserSettings: { authCredentials in
                guard let authCredentials else { return .default }
                let credential = Credential(authCredentials)
                return try await Authenticator(api: networking.apiService).getUserSettings(credential)
            }
        )
    }()

    #if DEBUG
        public static let testValue: UserSettingsClient = UserSettingsClient { _ in
            .init(
                password: .init(mode: .singlePassword),
                _2FA: .init(enabled: .both, registeredKeys: [])
            )
        }
    #endif
}

public extension DependencyValues {
    var userSettingsClient: UserSettingsClient {
        get { self[UserSettingsClient.self] }
        set { self[UserSettingsClient.self] = newValue }
    }
}
