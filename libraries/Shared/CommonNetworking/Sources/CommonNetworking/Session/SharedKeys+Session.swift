//
//  Created on 02/07/2026 by Max Kupetskyi.
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

import ProtonCoreDataModel
import ProtonCoreServices
import Sharing

// In-memory session state migrated off the legacy `PropertiesManager` plain stored properties.
// These are process-local (never persisted) and cleared on logout — matching the previous
// behaviour of holding them on the `PropertiesManager.default` singleton.

// `InMemoryKey` requires `Sendable`. These ProtonCore session values are set once per session and
// read from the main thread; the conformances are declared unchecked and locally (retroactive).
extension UserInfo: @retroactive @unchecked Sendable {}
extension UserSettings: @retroactive @unchecked Sendable {}
extension AccountRecovery: @retroactive @unchecked Sendable {}

public extension SharedKey where Self == InMemoryKey<UserInfo?>.Default {
    /// The authenticated user's info. Set after login/refresh, cleared on logout.
    static var userInfo: Self {
        Self[.inMemory("userInfo"), default: nil]
    }
}

public extension SharedKey where Self == InMemoryKey<UserSettings?>.Default {
    /// The authenticated user's settings. Set after login/refresh, cleared on logout.
    static var userSettings: Self {
        Self[.inMemory("userSettings"), default: nil]
    }
}

public extension SharedKey where Self == InMemoryKey<AccountRecovery?>.Default {
    /// The authenticated user's account-recovery state. Set after login/refresh, cleared on logout.
    static var userAccountRecovery: Self {
        Self[.inMemory("userAccountRecovery"), default: nil]
    }
}
