//
//  Created on 21.08.23.
//
//  Copyright (c) 2023 Proton AG
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

#if DEBUG
extension CachedVpnCredentials {
    static func plan(_ tier: Int) -> Self {
        .init(
            status: 0,
            planName: "Awesome", 
            planTitle: "does it matter?",
            maxConnect: 10,
            maxTier: tier,
            services: 1,
            delinquent: 0,
            credit: 1,
            currency: "Monopoly",
            hasPaymentMethod: true,
            subscribed: nil,
            businessEvents: false
        )
    }
}
#endif
