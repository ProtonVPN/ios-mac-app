//
//  SettingsTests.swift
//  ProtonVPNUITests
//
//  Created by Egle Predkelyte on 2021-08-20.
//  Copyright © 2021 Proton Technologies AG. All rights reserved.
//

import Foundation

class SettingsTests: ProtonVPNUITests {
    
    private let mainRobot = MainRobot()
    private let settingsRobot = SettingsRobot()
    
    override func setUp() {
        super.setUp()
        logInToProdIfNeeded()
    }
    
    func testKillSwitchAndLANConnectionOnOff() {
        
        mainRobot
            .goToSettingsTab()
            .turnKillSwitchOn()
            .verify.ksIsEnabled()
            .turnLanConnectionOn()
            .verify.lanConnectionIsEnabled()
    }
    
    func testSmartProtocolnOffAndOn() {
        
        mainRobot
            .goToSettingsTab()
            .goToProtocolsList()
            .smartProtocolOn()
            .returnToSettings()
            .verify.smartIsEnabled()
            .goToProtocolsList()
            .ikeProtocolOn()
            .returnToSettings()
            .verify.ikeIsEnabled()
    }
}
