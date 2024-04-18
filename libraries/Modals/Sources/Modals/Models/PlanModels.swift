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

public struct PlanDuration: Hashable {
    public static let oneMonth: Self = .init(components: .init(month: 1))!
    public static let threeMonths: Self = .init(components: .init(month: 3))!
    public static let oneYear: Self = .init(components: .init(year: 1))!
    public static let twoYears: Self = .init(components: .init(year: 2))!

    public let components: DateComponents

    public init?(components: DateComponents) {
        guard components.amountOfMonths > 0 else {
            return nil
        }
        self.components = components
    }
}

extension PlanDuration: CustomStringConvertible {
    public var description: String {
        return components.description
    }
}

public struct PlanPrice: Hashable {
    public static let loading: Self = .init(amount: 10, currency: "CHF")

    public let amount: Double
    public let currency: String
    public let locale: Locale

    public init(amount: Double, currency: String, locale: Locale = .current) {
        self.amount = amount
        self.currency = currency
        self.locale = locale
    }
}

public struct PlanOption: Hashable {
    public static let loading: Self = .init(duration: .oneYear, price: .loading)

    private static let minimumVisibleDiscount = 5

    public let duration: PlanDuration
    public let price: PlanPrice

    public var pricePerMonth: Double {
        price.amount / Double(duration.components.amountOfMonths)
    }

    public init(duration: PlanDuration, price: PlanPrice) {
        self.duration = duration
        self.price = price
    }
    
    public func discount(comparedTo plan: PlanOption) -> Int? {
        let pricePerMonthMine: Double = pricePerMonth
        let pricePerMonthTheirs: Double = plan.pricePerMonth
        if pricePerMonthTheirs == 0 {
            return nil
        } else if pricePerMonthMine == 0 {
            return 100
        }
        let discountDouble = (1 - (pricePerMonthMine / pricePerMonthTheirs)) * 100
        // don't round to 100% if it's not exactly 100%
        let discountInt = min(Int(discountDouble.rounded()), 99)
        return discountInt >= Self.minimumVisibleDiscount ? discountInt : nil
    }
}

// MARK: - Helpers

public extension DateComponents {
    var amountOfMonths: Int {
        (year ?? 0) * 12 + (month ?? 0)
    }
}
