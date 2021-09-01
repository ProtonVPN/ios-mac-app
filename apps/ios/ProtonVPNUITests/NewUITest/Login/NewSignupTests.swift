//
//  NewSignupTests.swift
//  ProtonVPNUITests
//
//  Created by Egle Predkelyte on 2021-09-01.
//  Copyright © 2021 Proton Technologies AG. All rights reserved.
//

import Foundation

class NewSignupTests: ProtonVPNUITests {
    
    let mainRobot = MainRobot()
    let newSignupTests = NewSignupTests()
    
    override func setUp() {
         super.setUp()
        logoutIfNeeded()
         mainRobot
             .changeEnvironmentTo()
     }

    func testCreateAccountWithProtonmail() {
        
        let email = "qa@protonmail.com"
    
        mainRobot
            .showSignup()
            .verify.signupScreenIsShown()
            .protonmailAccountNotAvailable(email)
            .verify.protonmailAccountErrorIsShown()
    }
    
    func testSwitchIntToLogin() {
    
        mainRobot
            .showSignup()
            .verify.signupScreenIsShown()
            .signinButtonTap()
            .verify.loginScreenIsShown()
    }
}
