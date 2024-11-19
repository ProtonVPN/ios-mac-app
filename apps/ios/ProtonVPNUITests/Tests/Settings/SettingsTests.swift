//
//  SettingsTests.swift
//  ProtonVPNUITests
//
//  Created by Egle Predkelyte on 2021-08-20.
//  Copyright © 2021 Proton Technologies AG. All rights reserved.
//

import Foundation
import UITestsHelpers

class SettingsTests: ProtonVPNUITests {
    
    override func setUp() {
        super.setUp()
        setupProdEnvironment()
        homeRobot
            .showLogin()
            .verify.loginScreenIsShown()
            .enterCredentials(UserType.Basic.credentials)
            .signIn(robot: HomeRobot.self)
            .verify.connectionStatusNotConnected()
    }
    
    func testKillSwitchAndLANConnectionOnOff() {
        
        homeRobot
            .goToSettingsTab()
            .turnKillSwitchOn()
            .verify.ksIsEnabled()
            .turnLanConnectionOn()
            .verify.lanConnectionIsEnabled()
    }
    
    func testSmartProtocolOffAndOn() {
        
        homeRobot
            .goToSettingsTab()
            .goToProtocolsList()
            .smartProtocolOn()
            .returnToSettings()
            .verify.smartIsEnabled()
            .goToProtocolsList()
            .stealthProtocolOn()
            .returnToSettings()
            .verify.stealthIsEnabled()
    }
}
