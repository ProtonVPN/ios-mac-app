//
//  Created on 07/07/2025 by Max Kupetskyi.
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

import Foundation
import Strings

public struct PlanOptionV2: Hashable {
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
    public var storePricePerMonth: Decimal

    var isMoreThanOneMonth: Bool {
        amountOfMonths > 1
    }

    public func renews(at date: String) -> String? {
        guard purchaseType == .web else {
            return nil
        }
        return Localizable.subscriptionRenewalDate(date, "US$79.95")
    }

    // MARK: - Init

    public init(
        id: String,
        storePricePerMonth: Decimal,
        amountOfMonths: Int,
        durationLabel: String?,
        displayPrice: String,
        pricePerMonth: String,
        purchaseType: PlanType = .iap
    ) {
        self.id = id
        self.storePricePerMonth = storePricePerMonth
        self.amountOfMonths = amountOfMonths
        self.durationLabel = durationLabel
        self.displayPrice = displayPrice
        self.pricePerMonth = pricePerMonth
        self.purchaseType = purchaseType
    }
}

public extension PlanOptionV2 {
    static var twoYearsWebPlan: Self {
        .init(
            id: "2YwebPlan",
            storePricePerMonth: 4.99,
            amountOfMonths: 24,
            durationLabel: "2 years",
            displayPrice: "$119.76",
            pricePerMonth: "$4.99",
            purchaseType: .web
        )
    }
}

// MARK: - Helpers

#if DEBUG
    public extension PlanOptionV2 {
        static var oneMonth: Self = PlanOptionV2(
            id: "1",
            storePricePerMonth: 9.95,
            amountOfMonths: 1,
            durationLabel: "1 month",
            displayPrice: "$9.95",
            pricePerMonth: "$9.95"
        )
        static var oneYear: Self = PlanOptionV2(
            id: "2",
            storePricePerMonth: 6.66,
            amountOfMonths: 12,
            durationLabel: "1 year",
            displayPrice: "$79.95",
            pricePerMonth: "$6.66"
        )
    }
#endif
