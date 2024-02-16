//
//  Created on 31/03/2022.
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

import XCTest
@testable import Modals

final class PlanOptionTests: XCTestCase {
    func testDiscountYearlyToMonthlyPlan() {
        let oneMonthPlan = PlanOption(duration: .oneMonth, price: .init(amount: 10, currency: "Cheetos"))
        let oneYearPlan = PlanOption(duration: .oneYear, price: .init(amount: 78, currency: "Cheerios"))

        XCTAssertNil(oneMonthPlan.discount(comparedTo: oneYearPlan))
        // 78 / 12 = 6.5
        // 6.5 / 10 = 0.65
        // 1 - 0.65 = 0.35
        XCTAssertEqual(oneYearPlan.discount(comparedTo: oneMonthPlan), 35)
    }

    func testDiscountLessThan5Percent() {
        let oneMonthPlan = PlanOption(duration: .oneMonth, price: .init(amount: 10, currency: "Tea Brick"))
        let oneYearPlan = PlanOption(duration: .oneYear, price: .init(amount: 119, currency: "Parmesan Cheese"))

        XCTAssertNil(oneMonthPlan.discount(comparedTo: oneYearPlan))
        // 119 / 12 = 9.92
        // 9.92 / 10 = 0.992
        // 1 - 0.992 = 0.008
        XCTAssertNil(oneYearPlan.discount(comparedTo: oneMonthPlan))
    }

    func testDiscountExactly5Percent() {
        let oneMonthPlan = PlanOption(duration: .oneMonth, price: .init(amount: 10, currency: "Salt"))
        let oneYearPlan = PlanOption(duration: .oneYear, price: .init(amount: 114, currency: "Beaver pelt"))

        XCTAssertNil(oneMonthPlan.discount(comparedTo: oneYearPlan))
        // 114 / 12 = 9.5
        // 9.5 / 10 = 0.95
        // 1 - 0.95 = 0.05
        XCTAssertEqual(oneYearPlan.discount(comparedTo: oneMonthPlan), 5)
    }

    func testDiscountWithNoDecimalPlaces() {
        let oneMonthPlan = PlanOption(duration: .oneMonth, price: .init(amount: 10, currency: "Dồng"))
        let oneYearPlan = PlanOption(duration: .oneYear, price: .init(amount: 113, currency: "Rai Stone"))

        XCTAssertNil(oneMonthPlan.discount(comparedTo: oneYearPlan))
        // 113 / 12 = 9.4166666667
        // 9.4166666667 / 10 = 0.94166666667
        // 1 - 0.94166666667 = 0.05833333333
        XCTAssertEqual(oneYearPlan.discount(comparedTo: oneMonthPlan), 6)
    }

    func testDiscountCloseTo100Percent() {
        let oneMonthPlan = PlanOption(duration: .oneMonth, price: .init(amount: 10, currency: "Knife Money"))
        let oneYearPlan = PlanOption(duration: .oneYear, price: .init(amount: 0.5, currency: "Sea shell"))

        XCTAssertNil(oneMonthPlan.discount(comparedTo: oneYearPlan))
        // 0.5 / 12 = 0.04
        // 0.04 / 10 = 0.004
        // 1 - 0.004 = 0.996
        XCTAssertEqual(oneYearPlan.discount(comparedTo: oneMonthPlan), 99)
    }

    func testDiscountExactly100Percent() {
        let oneMonthPlan = PlanOption(duration: .oneMonth, price: .init(amount: 10, currency: "Cacao bean"))
        let oneYearPlan = PlanOption(duration: .oneYear, price: .init(amount: 0, currency: "Squirrel pelt"))

        XCTAssertNil(oneMonthPlan.discount(comparedTo: oneYearPlan))
        XCTAssertEqual(oneYearPlan.discount(comparedTo: oneMonthPlan), 100)
    }
}
