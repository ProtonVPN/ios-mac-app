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

import struct Foundation.DateComponents

struct PlanDuration: Hashable {
    static let oneMonth: Self = .init(components: .init(month: 1))
    static let threeMonths: Self = .init(components: .init(month: 3))
    static let oneYear: Self = .init(components: .init(year: 1))
    static let twoYears: Self = .init(components: .init(year: 2))

    let components: DateComponents

    init(components: DateComponents) {
        self.components = components
    }
}

extension PlanDuration: CustomStringConvertible {
    var description: String {
        return components.description
    }
}

struct PlanPrice: Hashable {
    static let loading: Self = .init(amount: 10, currency: "CHF")

    let amount: Int
    let currency: String
    let discount: Int?

    init(amount: Int, currency: String, discount: Int? = nil) {
        self.amount = amount
        self.currency = currency
        self.discount = discount
    }
}

struct PlanOption: Hashable {
    let duration: PlanDuration
    let price: PlanPrice

    static let loading: Self = .init(duration: .oneYear, price: .loading)
}
