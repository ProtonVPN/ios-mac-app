//
//  Created on 2022-10-05.
//
//  Copyright (c) 2022 Proton AG
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
import PMLogger

public class MockAuthKeychain: AuthKeychainHandle {
    public var username: String?
    public var userId: String?

    public func saveToCache(_: VPNShared.AuthCredentials?) {}

    @Dependency(\.appInfo) private var appInfo

    var credentialsWereStored: (() -> Void)?
    var credentialsWereCleared: (() -> Void)?

    public init() {}

    var credentials: [AppContext: AuthCredentials] = [:]

    public func fetch(forContext context: AppContext?) throws -> AuthCredentials {
        guard let credentials = fetch(forContext: context) else {
            throw KeychainError.credentialsMissing("test-authkeychain-storage-key")
        }
        return credentials
    }

    public func fetch(forContext context: AppContext?) -> AuthCredentials? {
        credentials[context ?? .mainApp]
    }

    public func store(_ credentials: AuthCredentials, forContext context: AppContext?, source _: AuthCredentialsSource) throws {
        username = credentials.username
        self.credentials[context ?? .mainApp] = credentials
        credentialsWereStored?()
    }

    public func clear(_: ClearKeychainReason) {
        credentials = [:]
        credentialsWereCleared?()
    }
}

public extension MockAuthKeychain {
    func setMockUsername(_ username: String) {
        self.username = username
        credentials[.mainApp] = .init(
            username: username,
            accessToken: "",
            refreshToken: "",
            sessionId: "",
            userId: "",
            scopes: [],
            mailboxPassword: "",
            isCredentialLess: false
        )
    }
}
