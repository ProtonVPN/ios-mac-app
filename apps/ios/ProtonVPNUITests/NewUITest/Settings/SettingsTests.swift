//
//  SettingsTests.swift
//  ProtonVPNUITests
//
//  Created by Egle Predkelyte on 2021-08-23.
//  Copyright © 2021 Proton Technologies AG. All rights reserved.
//

import Foundation

class SettingsTests: ProtonVPNUITests {
    
    private let mainRobot = MainRobot()
    private let settingsRobot = SettingsRobot()
    
    func testKillSwitchAndLANConnectionOnOff() {
        
        logInIfNeeded()
        mainRobot
            .goToSettingsTab()
            .turnKillSwitchOn()
            .verify.ksIsEnabled()
            .turnLanCOnnectionhOn()
            .verify.lanConnectionIsEnabled()
    }
    
    func testSmartProtocolnOffAndOn() {
        
        logInIfNeeded()
        mainRobot
            .goToSettingsTab()
            .smartProtocolOff()
            .verify.smartProtocolIsDisabled()
            .smartProtocolOn()
            .verify.smartProtocolIsEnabled()
    }
}
