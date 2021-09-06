//
//  NeedHelpRobot.swift
//  ProtonVPNUITests
//
//  Created by Egle Predkelyte on 2021-09-01.
//  Copyright © 2021 Proton Technologies AG. All rights reserved.
//

import pmtest
import XCTest

private let helpTitleLabel = "HelpViewController.titleLabel"
private let helpViewCloseButtonId = "HelpViewController.closeButton"
private let forgotUsernameLabel = "Forgot username"
private let forgotPasswordLabel = "Forgot password"
private let otherSignInIssuesLabel = "Other sign-in issues"
private let customerSupportLabel = "Customer support"
private let forgotUsernamePageHeader = "Forgot Your Username?"
private let forgotPasswordPageHeader = "Reset Password"
private let commonLoginIssuesPageHeader = "Common Login Problems"
private let customerSupportPageHeader = "Support Form"

class NeedHelpRobot: CoreElements {
    
    public let safari = XCUIApplication(bundleIdentifier: "com.apple.mobilesafari")
    
    func needHelpOptionsDisplayed() -> NeedHelpRobot {
        button(helpViewCloseButtonId).checkExists()
        staticText(forgotUsernameLabel).checkExists()
        staticText(forgotPasswordLabel).checkExists()
        staticText(otherSignInIssuesLabel).checkExists()
        staticText(customerSupportLabel).checkExists()
        return self
    }
    
    func forgotUsernameLink() -> NeedHelpRobot {
        staticText(forgotUsernameLabel).tap()
        safari.staticTexts[forgotUsernamePageHeader].exists
        return NeedHelpRobot()
    }
    
    func forgotPasswordLink() -> NeedHelpRobot {
        staticText(forgotPasswordLabel).tap()
        safari.staticTexts[forgotPasswordPageHeader].exists
        return NeedHelpRobot()
    }
    
    func otherSignInIssuesLink() -> NeedHelpRobot {
        staticText(otherSignInIssuesLabel).tap()
        safari.staticTexts[commonLoginIssuesPageHeader].exists
        return NeedHelpRobot()
    }

    func customerSupportLink() {
         staticText(customerSupportLabel).tap()
         safari.staticTexts[customerSupportPageHeader].exists
     }

    func goBackToApp() -> NeedHelpRobot {
         XCUIApplication().activate()
         return self
     }
     
     func closeNeedHelpScreen() -> LoginRobot{
         button(helpViewCloseButtonId).wait().tap()
         return LoginRobot()
     }
}
