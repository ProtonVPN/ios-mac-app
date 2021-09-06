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
        logInIfNeeded()
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
            .smartProtocolOff()
            .verify.smartProtocolIsDisabled()
            .smartProtocolOn()
            .verify.smartProtocolIsEnabled()
    }
}
