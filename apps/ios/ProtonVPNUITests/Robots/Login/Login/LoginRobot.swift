//
//  LoginRobot.swift
//  ProtonVPNUITests
//
//  Created by Egle Predkelyte on 2021-09-01.
//  Copyright © 2021 Proton Technologies AG. All rights reserved.
//

import fusion
import ProtonCoreQuarkCommands

fileprivate let titleId = "LoginViewController.titleLabel"
fileprivate let subtitleId = "LoginViewController.subtitleLabel"
fileprivate let loginTextFieldId = "LoginViewController.loginTextField.textField"
fileprivate let passwordTextFieldId = "LoginViewController.passwordTextField.textField"
fileprivate let signInButtonId = "LoginViewController.signInButton"
fileprivate let invalidCredentialText = "The password is not correct. Please try again with a different password."
fileprivate let helpButtonId = "UINavigationItem.rightBarButtonItem"
fileprivate let enterPasswordErrorMessage = "Please enter your Proton Account password."
fileprivate let enterUsernameErrorMessage = "Please enter your Proton Account email or username."
fileprivate let errorBannerMessage = "Email address already used."
fileprivate let assignConnectionErrorBannerMessage = "subuserAlertDescription1"
fileprivate let okButton = "OK"
fileprivate let assignVPNConnectionButton = "Enable VPN connections"
fileprivate let loginButton = "Sign in again"
fileprivate let invalidUsernameErrorMessage = "Invalid username"
fileprivate let CaptchaNextButton = "Next"

class LoginRobot: CoreElements {
    
    public let verify = Verify()
    
    @discardableResult
    func enterCredentials(_ name: Credentials) -> LoginRobot {
        return typeUsername(username: name.username)
            .typePassword(password: name.password)
    }

    func enterCredentials(_ user: User) -> LoginRobot {
        return typeUsername(username: user.name)
            .typePassword(password: user.password)
    }

    @discardableResult
    func enterIncorrectCredentials(_ username: String, _ password: String) -> LoginRobot {
        return typeUsername(username: username)
            .typePassword(password: password)
    }
    
    @discardableResult
    func signIn<T: CoreElements>(robot _: T.Type) -> T {
        button(signInButtonId).tap()
        return T()
    }
    
    @discardableResult
    func verifyCaptcha() -> LoginRobot {
        button(CaptchaNextButton).tap()
        return LoginRobot()
    }
    
    private func typeUsername(username: String) -> LoginRobot {
        textField(loginTextFieldId).tap().typeText(username)
        return self
    }
    
    private func typePassword(password: String) -> LoginRobot {
        secureTextField(passwordTextFieldId).tap().typeText(password)
        return self
    }
    
    class Verify: CoreElements {
        
        @discardableResult
        func loginScreenIsShown() -> LoginRobot {
            staticText(titleId).waitUntilExists().checkExists()
            staticText(subtitleId).waitUntilExists().checkExists()
            textField(loginTextFieldId).tap()
            return LoginRobot()
        }
        
        @discardableResult
        func incorrectCredentialsErrorDialog() -> LoginRobot {
            textView(invalidCredentialText).waitUntilExists().checkExists()
            button(okButton).checkExists().tap()
            return LoginRobot()
        }
        
        @discardableResult
        func specialCharErrorDialog() -> LoginRobot {
            textView(invalidUsernameErrorMessage).waitUntilExists().checkExists()
            button(okButton).checkExists().tap()
            return LoginRobot()
        }
        
        @discardableResult
        func emailAddressAlreadyExists() -> LoginRobot {
            textView(errorBannerMessage).waitUntilExists().checkExists()
            button(okButton).waitUntilExists().checkExists().tap()
            return LoginRobot()
        }
        
        @discardableResult
        func assignVPNConnectionErrorIsShown() -> LoginRobot {
            staticText(assignConnectionErrorBannerMessage).waitUntilExists().checkExists()
            button(loginButton).waitUntilExists().checkExists().tap()
            return LoginRobot()
        }
        
        @discardableResult
        func correctUserIsLogedIn(_ name: Credentials) -> LoginRobot {
            staticText(name.username).checkExists()
            staticText(name.plan).checkExists()
            return LoginRobot()
        }
    }
}
