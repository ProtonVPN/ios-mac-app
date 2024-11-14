//
//  Created on 29/9/22.
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
import fusion
import XCTest

fileprivate let upgradeSubscriptionTitle = "Upgrade your plan"

class SubscriptionsRobot: CoreElements {

    let verify = Verify()

    class Verify: CoreElements {

        @discardableResult
        public func verifyTableCellStaticText(cellName: String, text: String) -> SubscriptionsRobot {
            let planCell = table("PaymentsUIViewController.tableView").onChild(cell(cellName))
            planCell.checkExists(message: "Plan cell \(cellName) is not visible")
            planCell.onChild(staticText(text)).checkExists(message: "Plan cell \(cellName) does not contain text \(text)")
            return SubscriptionsRobot()
        }

        @discardableResult
        func upgradeSubscriptionScreenShown() -> SubscriptionsRobot {
            staticText(upgradeSubscriptionTitle).checkExists(message: "\(upgradeSubscriptionTitle) screen not shown")
            return SubscriptionsRobot()
        }

        @discardableResult
        public func numberOfPlansToPurchaseIs(number: Int) -> SubscriptionsRobot {
            table("PaymentsUIViewController.tableView").waitUntilExists(time: 15).checkExists()
            // -1 because 1st cell is drop down
            let count = XCUIApplication().tables.matching(
                identifier: "PaymentsUIViewController.tableView"
            ).cells.count - 1
            XCTAssertEqual(count, number)
            return SubscriptionsRobot()
        }

        @discardableResult
        func checkDurationIs(_ length: String) -> SubscriptionsRobot {
            staticText().containsLabel(length).waitUntilExists().checkExists()
            return SubscriptionsRobot()
        }

        @discardableResult
        func checkPriceIs(_ price: String) -> SubscriptionsRobot {
            staticText().containsLabel(price).waitUntilExists().checkExists()
            return SubscriptionsRobot()
        }

        @discardableResult
        func checkPlanNameIs(_ name: String) -> SubscriptionsRobot {
            staticText(name).waitUntilExists().checkExists()
            return SubscriptionsRobot()
        }
    }
}
