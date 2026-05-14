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

public struct PlanOptionV2: Hashable, Sendable, Identifiable {
    private static let minimumVisibleDiscount = 5

    public enum PlanType: Hashable, Sendable {
        case iap
        case web
    }

    /// Whether or not the purchase is done using IAP or the web.
    public let purchaseType: PlanType

    /// The identifier of the plan, e.g., ioscore_core2023_12_usd_auto_renewing
    public let id: String

    /// The billing cycle of the plan.
    public let amountOfMonths: Int

    /// What label, if any, to use for the duration.
    public let durationLabel: String?

    /// What price is displayed for the given product bundle.
    ///
    /// - Note: if the product includes an offer, this is *not* reflected in `displayPrice`.
    public let displayPrice: String

    /// The introductory offer display price, if any.
    public let introDisplayPrice: String?

    /// The ``storePricePerMonth`` formatted for viewing.
    public let pricePerMonth: String

    /// Per-month price during the introductory offer, unformatted to calculate discounts.
    public let introPricePerMonth: Decimal?

    /// Per-month price during the introductory offer, formatted for viewing.
    public let introDisplayPricePerMonth: String?

    /// The price divided by the number of months in the billing cycle.
    public var storePricePerMonth: Decimal

    var isMoreThanOneMonth: Bool {
        amountOfMonths > 1
    }

    public var hasIntroOffer: Bool {
        introDisplayPrice != nil
    }

    public func introductoryFooter(renewingOn date: String) -> String? {
        let cycle: String

        if purchaseType == .web, amountOfMonths == 24 {
            // TODO: https://protonag.atlassian.net/browse/VPNAPPL-3103
            cycle = Localizable.perYear
        } else {
            if amountOfMonths == 12 {
                cycle = Localizable.perYear
            } else if amountOfMonths == 1 {
                cycle = Localizable.perMonth
            } else {
                assertionFailure("Plan of unknown billing cycle?")
                return nil
            }
        }

        return introDisplayPrice.map { _ in
            Localizable.introductoryPriceFooter(date, displayPrice, cycle)
        }
    }

    // MARK: - Init

    public init(
        id: String,
        storePricePerMonth: Decimal,
        amountOfMonths: Int,
        durationLabel: String?,
        displayPrice: String,
        introDisplayPrice: String?,
        pricePerMonth: String,
        introPricePerMonth: Decimal?,
        introDisplayPricePerMonth: String?,
        purchaseType: PlanType = .iap
    ) {
        self.id = id
        self.storePricePerMonth = storePricePerMonth
        self.amountOfMonths = amountOfMonths
        self.durationLabel = durationLabel
        self.displayPrice = displayPrice
        self.introDisplayPrice = introDisplayPrice
        self.pricePerMonth = pricePerMonth
        self.introPricePerMonth = introPricePerMonth
        self.introDisplayPricePerMonth = introDisplayPricePerMonth
        self.purchaseType = purchaseType
    }
}

// MARK: - Helpers

public extension PlanOptionV2 {
    /// This value is hard-coded.
    ///
    /// It's also slightly different from the other offers because the introductory price is
    /// *higher*, since the introductory offer is for the first two years, while the plan
    /// renews on a 1-year cycle.
    ///
    /// - Todo: https://protonag.atlassian.net/browse/VPNAPPL-3103
    static let twoYearsWebPlan: Self = PlanOptionV2(
        id: "2YwebPlan",
        storePricePerMonth: 4.99,
        amountOfMonths: 24,
        durationLabel: "2 years",
        displayPrice: "$79.95",
        introDisplayPrice: "$119.76",
        pricePerMonth: "$6.66",
        introPricePerMonth: 4.99,
        introDisplayPricePerMonth: "$4.99",
        purchaseType: .web
    )
}

#if DEBUG
    public extension PlanOptionV2 {
        static let oneMonth: Self = PlanOptionV2(
            id: "1",
            storePricePerMonth: 9.95,
            amountOfMonths: 1,
            durationLabel: "1 month",
            displayPrice: "$9.95",
            introDisplayPrice: "$1.00",
            pricePerMonth: "$9.95",
            introPricePerMonth: 1.00,
            introDisplayPricePerMonth: "$1.00"
        )
        static let oneYear: Self = PlanOptionV2(
            id: "2",
            storePricePerMonth: 6.66,
            amountOfMonths: 12,
            durationLabel: "1 year",
            displayPrice: "$79.95",
            introDisplayPrice: "$49.95",
            pricePerMonth: "$6.66",
            introPricePerMonth: 4.16,
            introDisplayPricePerMonth: "$4.16"
        )
    }
#endif
