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

import XCTest
import fusion
import UITestsHelpers

class PlanTests: ProtonVPNUITests {

    private let loginRobot = LoginRobot()

    private struct Plan {
        let name: String
        let duration: String
        let price: String
        let user: Credentials
    }

    private let vpnPlusPlan = Plan(
        name: "VPN Plus",
        duration: "1 year",
        price: "71,88",
        user: BF22Users.plusUser.credentials
    )

    private let vpnPlus15MonthPlan = Plan(
        name: "VPN Plus",
        duration: "15 months",
        price: "149,85",
        user: BF22Users.cycle15User.credentials
    )

    private let vpnPlus30MonthPlan = Plan(
        name: "VPN Plus",
        duration: "30 months",
        price: "299,70",
        user: BF22Users.cycle30User.credentials
    )

    override func setUp() {
        super.setUp()
        setupAtlasEnvironment()
        mainRobot
            .showLogin()
            .verify.loginScreenIsShown()
    }

    /// Tests that the plan for the VPN Plus user is named "VPN Plus", lasts for 1 year and costs $99.99
    func testShowCurrentPlanForVPNPlusUser() {
        testShowCurrentPlan(vpnPlusPlan)
    }

    // Black Friday 2022 plans, will renew at same price and cycle, so we want to keep tests for them

    /// Tests that the plan for the VPN Plus user is named "VPN Plus", lasts for 15 months and costs $149.85
    func testShowCurrentPlanForVPNPlus15MUser() {
        testShowCurrentPlan(vpnPlus15MonthPlan)
    }

    /// Tests that the plan for the VPN Plus user is named "VPN Plus", lasts for 30 months and costs $299.70
    func testShowCurrentPlanForVPNPlus30MUser() {
        testShowCurrentPlan(vpnPlus30MonthPlan)
    }

    // This test temporary disabled
    /// Test showing standard plans for upgrade but not Black Friday 2022 plans
    func testShowUpdatePlansForCurrentFreePlan() {
        
        loginAndGoToAccountDetails(BF22Users.freeUser.credentials)
            .goToUpgradeSubscription()
            .verify.upgradeSubscriptionScreenShown()
            .verify.numberOfPlansToPurchaseIs(number: 2)
            .verify.verifyTableCellStaticText(cellName: "PlanCell.Proton_Unlimited", text: "Proton Unlimited")
            .verify.verifyTableCellStaticText(cellName: "PlanCell.Proton_Unlimited", text: "for 1 year")
            .verify.verifyTableCellStaticText(cellName: "PlanCell.Proton_Unlimited", text: "$149,99")
            .verify.verifyTableCellStaticText(cellName: "PlanCell.VPN_Plus", text: "VPN Plus")
            .verify.verifyTableCellStaticText(cellName: "PlanCell.VPN_Plus", text: "for 1 year")
            .verify.verifyTableCellStaticText(cellName: "PlanCell.VPN_Plus", text: "$99,99")
    }

    private func loginAndGoToAccountDetails(_ user: Credentials) -> AccountRobot {
        return loginRobot
            .enterCredentials(user)
            .signIn(robot: MainRobot.self)
            .verify.connectionStatusNotConnected()
            .goToSettingsTab()
            .goToAccountDetail()
    }

    private func testShowCurrentPlan(_ plan: Plan) {
        loginAndGoToAccountDetails(plan.user)
            .goToManageSubscription()
            .verify.checkPlanNameIs(plan.name)
            .verify.checkDurationIs(plan.duration)
            .verify.checkPriceIs(plan.price)
    }
}
