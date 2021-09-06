//
//  LoginRobot.swift
//  ProtonVPNUITests
//
//  Created by Egle Predkelyte on 2021-09-01.
//  Copyright © 2021 Proton Technologies AG. All rights reserved.
//

import pmtest

fileprivate let titleId = "LoginViewController.titleLabel"
fileprivate let subtitleId = "LoginViewController.subtitleLabel"
fileprivate let loginTextFieldId = "LoginViewController.loginTextField.textField"
fileprivate let passwordTextFieldId = "LoginViewController.passwordTextField.textField"
fileprivate let signInButtonId = "LoginViewController.signInButton"
fileprivate let invalidCredentialText = "Incorrect login credentials. Please try again"
fileprivate let helpButtonId = "LoginViewController.helpButton"
fileprivate let enterPasswordErrorMessage = "Please enter your Proton Account password."
fileprivate let enterUsernameErrorMessage = "Please enter your Proton Account email or username."

class LoginRobot: CoreElements {
    
    public let verify = Verify()
    
    @discardableResult
    func loginUser(credentials: Credentials) -> LoginRobot {
        return typeUsername(username: credentials.username)
            .typePassword(password: credentials.password)
            .signIn()
    }
    
    @discardableResult
    func loginWrongUser(_ username: String, _ password: String) -> LoginRobot {
        return typeUsername(username: username)
            .typePassword(password: password)
            .signIn()
    }
    
    @discardableResult
    func loginEmptyFields() -> LoginRobot {
        return signIn()
    }
    
    func needHelp() -> NeedHelpRobot {
        button(helpButtonId).tap()
        return NeedHelpRobot()
    }

    
    private func typeUsername(username: String) -> LoginRobot {
        textField(loginTextFieldId).tap().typeText(username)
        return self
    }
    
    private func typePassword(password: String) -> LoginRobot {
        secureTextField(passwordTextFieldId).tap()
        secureTextField(passwordTextFieldId).tap().typeText(password)
        return self
    }
    
    private func signIn() -> LoginRobot {
        button(signInButtonId).tap()
        return self
    }
    
    class Verify: CoreElements {
        
        @discardableResult
        func loginScreenIsShown() -> LoginRobot {
            staticText(titleId).wait().checkExists()
            staticText(subtitleId).wait().checkExists()
            return LoginRobot()
        }
        
        @discardableResult
        func incorrectCredentialsErrorDialog() -> LoginRobot {
            textView(invalidCredentialText).wait().checkExists()
            return LoginRobot()
        }
        
        @discardableResult
        func pleaseEnterPasswordAndUsernameErrorIsShown() -> LoginRobot {
            staticText(enterPasswordErrorMessage).checkExists()
            staticText(enterUsernameErrorMessage).checkExists()
            return LoginRobot()
        }
    }
}
