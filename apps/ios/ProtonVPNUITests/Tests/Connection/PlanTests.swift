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
import pmtest

class PlanTests: ProtonVPNUITests {

    private let mainRobot = MainRobot()

    private let credentialsBF22 = Credentials.loadFrom(plistUrl: Bundle(identifier: "ch.protonmail.vpn.ProtonVPNUITests")!.url(forResource: "credentials_bf22", withExtension: "plist")!)

    override func setUp() {
        super.setUp()

        logoutIfNeeded()
        changeEnvToBF22IfNeeded()
        openLoginScreen()

    }

    /// Tests that the plan for the VPN Plus user is named "VPN Plus", lasts for 1 year and costs $71.88
    func testShowCurrentPlanForVPNPlusUser() {

        loginAsPlusUser()

        mainRobot
            .goToSettingsTab()
            .goToAccountDetail()
            .goToUpgradeSubscription()
            .checkPlanNameIs("VPN Plus")
            .checkDurationIs("for 1 year")
        // ⬇︎ Uncomment after CP-4705 (Core > 3.22.4) is merged in
        // .checkPriceIs("$71.88")
    }

    // Black Friday 2022 plans, will renew at same price and cycle, so we want to keep tests for them

    /// Tests that the plan for the VPN Plus user is named "VPN Plus", lasts for 15 months and costs $149.85
    func testShowCurrentPlanForVPNPlus15MUser() {
        loginAsBF22YearPlusUser()

        mainRobot
            .goToSettingsTab()
            .goToAccountDetail()
            .goToUpgradeSubscription()
            .checkPlanNameIs("VPN Plus")
            .checkDurationIs("for 1 year") // should be "for 15 months" after CP-4611
            .checkPriceIs("$149.85")
    }

    /// Tests that the plan for the VPN Plus user is named "VPN Plus", lasts for 30 months and costs $299.70
    func testShowCurrentPlanForVPNPlus30MUser() {
        loginAsBF22TwoYearPlusUser()

        mainRobot
            .goToSettingsTab()
            .goToAccountDetail()
            .goToUpgradeSubscription()
            .checkPlanNameIs("VPN Plus")
            .checkDurationIs("for 2 years") // should be "for 30 months" after CP-4611
            .checkPriceIs("$299.70")
    }

    override func loginAsPlusUser() {
        login(withCredentials: credentialsBF22[0])
    }

    func loginAsBF22YearPlusUser() {
        login(withCredentials: credentialsBF22[1])
    }

    func loginAsBF22TwoYearPlusUser() {
        login(withCredentials: credentialsBF22[2])
    }

    private func changeEnvToBF22IfNeeded() {
        let env = app.staticTexts[ObfuscatedConstants.bf22DefaultHost + ObfuscatedConstants.bf22DefaultPath]

        if env.waitForExistence(timeout: 10){
            return
        }
        else {
            changeEnvToBF22()
            app.launch()
        }
    }

    private func changeEnvToBF22() {
        let textFields = app.textFields["https://"]
        textFields.tap()
        textFields.typeText(ObfuscatedConstants.bf22DefaultHostWithoutHttps + ObfuscatedConstants.bf22DefaultPath)
        app.buttons["Change and kill the app"].tap()
        app.buttons["OK"].tap()
    }
}
