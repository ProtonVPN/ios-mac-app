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
import VPNShared

public final class NATTypePropertyProviderMock: NATTypePropertyProvider {
    public static var natTypeNotification: Notification.Name = NSNotification.Name("")

    public var factory: Factory

    public required init(_ factory: Factory) {
        self.factory = factory
    }

    public convenience init() {
        self.init(PaidFeaturePropertyProviderFactoryMock())
    }

    public var natType: NATType = .default

    public var isUserEligibleForNATTypeChange = true

    public func adjustAfterPlanChange(from oldTier: Int, to tier: Int) {
        if tier <= CoreAppConstants.VpnTiers.free {
            natType = .default
        }
    }
}
