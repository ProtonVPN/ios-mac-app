//
//  NewLoginTests.swift
//  ProtonVPNUITests
//
//  Created by Egle Predkelyte on 2021-09-01.
//  Copyright © 2021 Proton Technologies AG. All rights reserved.
//

import Foundation

class LoginTests: ProtonVPNUITests {
    
    let mainRobot = MainRobot()
    let loginRobot = LoginRobot()
    let needHelpRobot = NeedHelpRobot()
    
    override func setUp() {
        super.setUp()
        logoutIfNeeded()
        changeEnvToProdIfNedded()
        useAndContinueTap()
        mainRobot
            .showLogin()
            .verify.loginScreenIsShown()
    }
    
    func testLoginWithIncorrectCredentials() {
        
        let username = "wrong_username"
        let userpassword = "wrong_password"
            
        loginRobot
            .loginWrongUser(username, userpassword)
            .verify.incorrectCredentialsErrorDialog()
    }
    
    func testLoginWithCorrectCredentials() {
        let credentials = Credentials.loadFrom(plistUrl: Bundle(identifier: "ch.protonmail.vpn.ProtonVPNUITests")!.url(forResource: "credentials", withExtension: "plist")!)
        
        for credential in credentials {
            login(withCredentials: credential)
            logoutIfNeeded()
            openLoginScreen()
        }
    }
    
    func testLoginAsSubuserWithNoConnectionsAssigned () {
        
        let subusercredentials = Credentials.loadFrom(plistUrl: Bundle(identifier: "ch.protonmail.vpn.ProtonVPNUITests")!.url(forResource: "subusercredentials", withExtension: "plist")!)

        loginRobot
            .loginAsSubuser(subusercredentials: subusercredentials[0])
            .verify.assignVPNConnectionErrorIsShown()
    }
    
    func testNeedHelpClosed() {
        
        loginRobot
            .needHelp()
            .needHelpOptionsDisplayed()
            .closeNeedHelpScreen()
            .verify.loginScreenIsShown()
    }
    
    func testNeedHelpOptionsLink() {
        
        mainRobot
            .showLogin()
            .needHelp()
            .needHelpOptionsDisplayed()
            .forgotUsernameLink()
            .goBackToApp().forgotPasswordLink()
            .goBackToApp().otherSignInIssuesLink()
            .goBackToApp().customerSupportLink()
    }
}
