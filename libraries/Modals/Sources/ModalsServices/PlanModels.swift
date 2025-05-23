//
//  Created on 28/02/2024.
//
//  Copyright (c) 2024 Proton AG
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
import Strings

public struct PlanOption: Hashable {
    private static let minimumVisibleDiscount = 5

    public enum PlanType: Hashable {
        case iap
        case web
    }

    public let purchaseType: PlanType
    public let id: String
    public let amountOfMonths: Int
    public let durationLabel: String?
    public let displayPrice: String
    public let pricePerMonth: String

    var isMoreThanOneMonth: Bool {
        amountOfMonths > 1
    }

    // MARK: - Init
    public init(
        id: String,
        amountOfMonths: Int,
        durationLabel: String?,
        displayPrice: String,
        pricePerMonth: String,
        purchaseType: PlanType = .iap
    ) {
        self.id = id
        self.amountOfMonths = amountOfMonths
        self.durationLabel = durationLabel
        self.displayPrice = displayPrice
        self.pricePerMonth = pricePerMonth
        self.purchaseType = purchaseType
    }
}

public extension PlanOption {
    static var twoYearsWebPlan: Self {
        .init(duration: .twoYears, price: .init(amount: 119.76, currency: "USD"), purchaseType: .web)
    }
}

// MARK: - Helpers

#if DEBUG
public extension PlanOption {
    static var oneMonth: Self = PlanOption(id: "1", amountOfMonths: 1, durationLabel: "1 month", displayPrice: "$9.95", pricePerMonth: "$9.95")
    static var oneYear: Self = PlanOption(id: "2", amountOfMonths: 12, durationLabel: "1 year", displayPrice: "$79.95", pricePerMonth: "$6.66")
}
#endif
