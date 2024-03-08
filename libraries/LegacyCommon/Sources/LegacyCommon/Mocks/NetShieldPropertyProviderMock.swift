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

import Domain
import VPNShared

public final class NetShieldPropertyProviderMock: NetShieldPropertyProvider {
    public var lastActiveNetShieldType: NetShieldType = .level1

    public static var netShieldNotification: Notification.Name = Notification.Name("")

    public var netShieldType: NetShieldType = .off {
        didSet {
            NotificationCenter.default.post(name: Self.netShieldNotification, object: self)
        }
    }

    public func adjustAfterPlanChange(from oldTier: Int, to tier: Int) {
        // Turn NetShield off on downgrade to free plan
        if tier.isFreeTier {
            netShieldType = .off
        }
        // Switch NetShield to level 1 on any upgrade from free plan
        if tier > oldTier && oldTier.isFreeTier {
            netShieldType = .level1
        }
    }
    
    public init() {}
}
#endif
