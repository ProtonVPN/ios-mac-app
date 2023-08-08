//
//  Created on 18.02.2022.
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

#if DEBUG
import Foundation
import VPNShared
import VPNSharedTesting

public final class PaidFeaturePropertyProviderFactoryMock: PaidFeaturePropertyProvider.Factory {
    let propertiesManager: PropertiesManagerMock
    let userTierProviderMock: UserTierProviderMock
    let authKeychain: AuthKeychainHandle

    public init(
        propertiesManager: PropertiesManagerMock = PropertiesManagerMock(),
        userTierProviderMock: UserTierProviderMock = UserTierProviderMock(CoreAppConstants.VpnTiers.basic),
        authKeychainMock: MockAuthKeychain = MockAuthKeychain(context: .mainApp)
    ) {
        self.propertiesManager = propertiesManager
        self.userTierProviderMock = userTierProviderMock
        self.authKeychain = authKeychainMock
    }

    public func makePropertiesManager() -> PropertiesManagerProtocol {
        return propertiesManager
    }

    public func makeUserTierProvider() -> UserTierProvider {
        return userTierProviderMock
    }

    public func makeAuthKeychainHandle() -> AuthKeychainHandle {
        return authKeychain
    }

}
#endif
