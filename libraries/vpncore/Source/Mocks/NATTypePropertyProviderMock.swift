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

import Foundation

public final class NATTypePropertyProviderMock: NATTypePropertyProvider {
    public static var natTypeNotification: Notification.Name = NSNotification.Name("")

    public var factory: Factory

    public required init(_ factory: Factory, storage: Storage, userInfoProvider: UserInfoProvider) {
        self.factory = factory
    }

    public convenience init() {
        self.init(PaidFeaturePropertyProviderFactoryMock(), storage: Storage(), userInfoProvider: AuthKeychain())
    }

    public var natType: NATType = .default

    public var isUserEligibleForNATTypeChange = true

    public func resetForIneligibleUser() {
        natType = .default
    }
}
