//
//  Created on 02/10/2025 by Max Kupetskyi.
//
//  Copyright (c) 2025 Proton AG
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

import Dependencies
import VPNShared

public struct CredentiallessManager {
    public var isCredentialless: () -> Bool
}

public struct CredentiallessManagerDependencyKey: DependencyKey {
    public static let liveValue: CredentiallessManager = .init(isCredentialless: {
        @Dependency(\.authKeychain) var authKeychain
        @Dependency(\.unauthKeychain) var unauthKeychain
        let userIsCredentialLess = authKeychain.fetch()?.isCredentialLess ?? unauthKeychain.fetch()?.isCredentialLess ?? false
        return userIsCredentialLess
    })
    public static let testValue: CredentiallessManager = .init(isCredentialless: { false })
}

public extension DependencyValues {
    var credentiallessManager: CredentiallessManager {
        get { self[CredentiallessManagerDependencyKey.self] }
        set { self[CredentiallessManagerDependencyKey.self] = newValue }
    }
}
