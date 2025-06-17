//
//  PasswordRobot.swift
//  ProtonVPNUITests
//
//  Created by Egle Predkelyte on 2021-09-15.
//  Copyright © 2021 Proton Technologies AG. All rights reserved.
//

import fusion

private let accountVerificationTitle = "PasswordViewController.createPasswordTitleLabel"
private let passwordNameTextFieldId = "PasswordViewController.passwordTextField.textField"
private let repeatPasswordNameTextFieldId = "PasswordViewController.repeatPasswordTextField.textField"
private let nextButtonId = "PasswordViewController.nextButton"

class PasswordRobot: CoreElements {
    public let verify = Verify()

    func enterPassword(_ password1: String) -> PasswordRobot {
        secureTextField(passwordNameTextFieldId).typeText(password1)
        return PasswordRobot()
    }

    func enterRepeatPassword(_ password2: String) -> PasswordRobot {
        secureTextField(repeatPasswordNameTextFieldId).tap().typeText(password2)
        return PasswordRobot()
    }

    func nextButtonTap<T: CoreElements>(robot _: T.Type) -> T {
        button(nextButtonId).tap()
        return T()
    }

    class Verify: CoreElements {
        @discardableResult
        func passwordScreenIsShown() -> PasswordRobot {
            staticText(accountVerificationTitle).waitUntilExists(time: 20).checkExists()
            return PasswordRobot()
        }
    }
}
