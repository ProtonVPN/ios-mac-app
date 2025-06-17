//
//  LoginRobot.swift
//  ProtonVPNUITests
//
//  Created by Egle Predkelyte on 2021-09-01.
//  Copyright © 2021 Proton Technologies AG. All rights reserved.
//

import fusion
import ProtonCoreQuarkCommands
import Strings
import UITestsHelpers

private let titleId = "LoginViewController.titleLabel"
private let subtitleId = "LoginViewController.subtitleLabel"
private let loginTextFieldId = "LoginViewController.loginTextField.textField"
private let passwordTextFieldId = "LoginViewController.passwordTextField.textField"
private let signInButtonId = "LoginViewController.signInButton"
private let invalidCredentialText = "The password is not correct. Please try again with a different password."
private let helpButtonId = "UINavigationItem.rightBarButtonItem"
private let enterPasswordErrorMessage = "Please enter your Proton Account password."
private let enterUsernameErrorMessage = "Please enter your Proton Account email or username."
private let errorBannerMessage = "Email address already used."
private let assignConnectionErrorBannerMessage = "subuserAlertDescription1"
private let okButton = Localizable.ok
private let loginButton = "Sign in again"
private let invalidUsernameErrorMessage = "Invalid username"
private let captchaNextButton = Localizable.modalsCommonNext

class LoginRobot: CoreElements {
    public let verify = Verify()

    @discardableResult
    func enterCredentials(_ name: Credentials) -> LoginRobot {
        typeUsername(username: name.username)
            .typePassword(password: name.password)
    }

    func enterCredentials(_ user: User) -> LoginRobot {
        typeUsername(username: user.name)
            .typePassword(password: user.password)
    }

    @discardableResult
    func enterIncorrectCredentials(_ username: String, _ password: String) -> LoginRobot {
        typeUsername(username: username)
            .typePassword(password: password)
    }

    @discardableResult
    func signIn<T: CoreElements>(robot _: T.Type) -> T {
        button(signInButtonId).tap()
        return T()
    }

    @discardableResult
    func verifyCaptcha() -> LoginRobot {
        button(captchaNextButton).tap()
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
        func loginScreenIsNotShown() -> LoginRobot {
            staticText(titleId)
                .waitUntilGone(time: 30)
                .checkDoesNotExist(message: "Login screen is still visible in 30 seconds")
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
    }
}
