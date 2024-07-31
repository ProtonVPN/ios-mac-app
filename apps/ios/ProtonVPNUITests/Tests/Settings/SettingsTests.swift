//
//  SettingsTests.swift
//  ProtonVPNUITests
//
//  Created by Egle Predkelyte on 2021-08-20.
//  Copyright © 2021 Proton Technologies AG. All rights reserved.
//

import Foundation

class SettingsTests: ProtonVPNUITests {
    
    private let settingsRobot = SettingsRobot()
    
    private lazy var credentials = getCredentials(from: "credentials")
    
    override func setUp() {
        super.setUp()
        setupProdEnvironment()
        mainRobot
            .showLogin()
            .verify.loginScreenIsShown()
            .enterCredentials(credentials[1])
            .signIn(robot: MainRobot.self)
            .verify.connectionStatusNotConnected()
    }
    
    func testKillSwitchAndLANConnectionOnOff() {
        
        mainRobot
            .goToSettingsTab()
            .turnKillSwitchOn()
            .verify.ksIsEnabled()
            .turnLanConnectionOn()
            .verify.lanConnectionIsEnabled()
    }
    
    func testSmartProtocolOffAndOn() {
        
        mainRobot
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
