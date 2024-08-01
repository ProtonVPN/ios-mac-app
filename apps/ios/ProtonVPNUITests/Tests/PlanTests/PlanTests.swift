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

class PlanTests: ProtonVPNUITests {

    private let loginRobot = LoginRobot()

    private lazy var credentialsBF22 = getCredentials(from: "credentials_bf22")
    
    enum BFCredentialsKey: Int {
        case plusUser = 0
        case cycle15User = 1
        case cycle30User = 2
        case freeUser = 3
    }

    override func setUp() {
        super.setUp()
        setupAtlasEnvironment()
        mainRobot
            .showLogin()
            .verify.loginScreenIsShown()
    }

    /// Tests that the plan for the VPN Plus user is named "VPN Plus", lasts for 1 year and costs $99.99
    func testShowCurrentPlanForVPNPlusUser() {

        loginRobot
            .enterCredentials(credentialsBF22[BFCredentialsKey.plusUser])
            .signIn(robot: MainRobot.self)
            .verify.connectionStatusNotConnected()
            .goToSettingsTab()
            .goToAccountDetail()
            .goToManageSubscription()
            .checkPlanNameIs("VPN Plus")
            .checkDurationIs("1 year")
            .checkPriceIs("59.99")
    }

    // Black Friday 2022 plans, will renew at same price and cycle, so we want to keep tests for them

    /// Tests that the plan for the VPN Plus user is named "VPN Plus", lasts for 15 months and costs $149.85
    func testShowCurrentPlanForVPNPlus15MUser() {

        loginRobot
            .enterCredentials(credentialsBF22[BFCredentialsKey.cycle15User])
            .signIn(robot: MainRobot.self)
            .verify.connectionStatusNotConnected()
            .goToSettingsTab()
            .goToAccountDetail()
            .goToManageSubscription()
            .checkPlanNameIs("VPN Plus")
            .checkDurationIs("15 months")
            .checkPriceIs("149.85")
    }

    /// Tests that the plan for the VPN Plus user is named "VPN Plus", lasts for 30 months and costs $299.70
    func testShowCurrentPlanForVPNPlus30MUser() {

        loginRobot
            .enterCredentials(credentialsBF22[BFCredentialsKey.cycle30User])
            .signIn(robot: MainRobot.self)
            .verify.connectionStatusNotConnected()
            .goToSettingsTab()
            .goToAccountDetail()
            .goToManageSubscription()
            .checkPlanNameIs("VPN Plus")
            .checkDurationIs("30 months")
            .checkPriceIs("299.70")
    }

    // This test temporary disabled
    /// Test showing standard plans for upgrade but not Black Friday 2022 plans
    func testShowUpdatePlansForCurrentFreePlan() {
        
        loginRobot
            .enterCredentials(credentialsBF22[BFCredentialsKey.freeUser])
            .signIn(robot: MainRobot.self)
            .verify.connectionStatusNotConnected()
            .goToSettingsTab()
            .goToAccountDetail()
            .goToUpgradeSubscription()
            .verifyStaticText("Upgrade your plan")
            .verifyNumberOfPlansToPurchase(number: 2)
            .verifyTableCellStaticText(cellName: "PlanCell.VPN_Plus", name: "VPN Plus")
            .verifyTableCellStaticText(cellName: "PlanCell.Proton_Unlimited", name: "Proton Unlimited")
            .verifyTableCellStaticText(cellName: "PlanCell.Proton_Unlimited", name: "for 1 year")
            .verifyTableCellStaticText(cellName: "PlanCell.Proton_Unlimited", name: "$149.99")
            .verifyTableCellStaticText(cellName: "PlanCell.VPN_Plus", name: "VPN Plus")
            .verifyTableCellStaticText(cellName: "PlanCell.VPN_Plus", name: "for 1 year")
            .verifyTableCellStaticText(cellName: "PlanCell.VPN_Plus", name: "$99.99")
    }
}
