//
//  Created on 04/05/2026 by John Biggs.
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

import Foundation
import StoreKit

public extension Product.SubscriptionOffer {
    /// Effective per-month price during the offer, derived from `period`, `periodCount`, and `paymentMode`.
    /// Returns `nil` for sub-month periods (days, weeks).
    var monthlyPrice: Decimal? {
        let monthsPerPeriod: Int = switch period.unit {
        case .day, .week:
            0
        case .month:
            period.value
        case .year:
            period.value * 12
        @unknown default:
            0
        }
        let totalMonths = monthsPerPeriod * periodCount
        guard totalMonths > 0 else { return nil }
        // `payAsYouGo` charges `price` per period; `payUpFront` and `freeTrial` are billed once.
        let totalPrice: Decimal = paymentMode == .payAsYouGo
            ? price * Decimal(periodCount)
            : price
        return totalPrice / Decimal(totalMonths)
    }
}
