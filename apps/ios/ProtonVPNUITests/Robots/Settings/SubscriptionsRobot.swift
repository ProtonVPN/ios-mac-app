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
import pmtest
import XCTest

class SubscriptionsRobot: CoreElements {

    @discardableResult
    func checkDurationIs(_ length: String) -> Self {
        staticText(length).wait().checkExists()
        return self
    }

    @discardableResult
    func checkPriceIs(_ price: String) -> Self {
        staticText(price).wait().checkExists()

        return self
    }

    @discardableResult
    func checkPlanNameIs(_ name: String) -> Self {
        staticText(name).wait().checkExists()

        return self
    }
    
    @discardableResult
    func verifyStaticText(_ name: String) -> Self {
        staticText(name).wait().checkExists()
        return self
    }
    
    @discardableResult
    public func verifyNumberOfPlansToPurchase(number: Int) -> Self {
        table("PaymentsUIViewController.tableView").wait().checkExists()
        let count = XCUIApplication().tables.matching(identifier: "PaymentsUIViewController.tableView").cells.count
        XCTAssertEqual(count, number)
        return self
    }
    
    @discardableResult
    public func sleepFor(_ duration: UInt32) -> Self {
        sleep(duration)
        return self
    }

    @discardableResult
    public func verifyTableCellStaticText(cellName: String, name: String) -> Self {
        table("PaymentsUIViewController.tableView").wait().checkExists()
        let staticTexts = XCUIApplication().tables.matching(identifier: "PaymentsUIViewController.tableView").cells.matching(identifier: cellName).staticTexts
        XCTAssertTrue(staticTexts[name].exists)
        return self
    }
}
