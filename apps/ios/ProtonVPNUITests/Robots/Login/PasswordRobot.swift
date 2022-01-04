//
//  PasswordRobot.swift
//  ProtonVPNUITests
//
//  Created by Egle Predkelyte on 2021-09-15.
//  Copyright © 2021 Proton Technologies AG. All rights reserved.
//

import pmtest

fileprivate let backButton = "UINavigationItem.leftBarButtonItem"
fileprivate let accountVerificationTitle = "PasswordViewController.createPasswordTitleLabel"
fileprivate let passwordNameTextFieldId = "PasswordViewController.passwordTextField.textField"
fileprivate let repeatPasswordNameTextFieldId = "PasswordViewController.repeatPasswordTextField.textField"
fileprivate let nextButtonId = "PasswordViewController.nextButton"
fileprivate let errorBannerButton = "OK"
fileprivate let errorBannerPassNotEqual = "Passwords do not match."
fileprivate let errorBannerPassTooShort = "Password must contain at least 8 characters."
fileprivate let errorBannerPassEmpty = "Password can not be empty."
fileprivate let errorBannerTryAgain = "Please try again."

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
            staticText(accountVerificationTitle).wait(time: 20).checkExists()
            return PasswordRobot()
        }
        
        @discardableResult
        func passwordTooShort() -> PasswordRobot {
            textView(errorBannerPassTooShort).wait(time: 10).checkExists()
            button(errorBannerButton).tap()
            return PasswordRobot()
        }
        
        @discardableResult
        func passwordNotEqual() -> PasswordRobot {
            textView(errorBannerPassNotEqual).wait(time: 10).checkExists()
            button(errorBannerButton).tap()
            return PasswordRobot()
        }
        
        @discardableResult
        func passwordEmpty() -> PasswordRobot {
            textView(errorBannerPassEmpty).wait(time: 10).checkExists()
            textView(errorBannerTryAgain).wait(time: 10).checkExists()
            button(errorBannerButton).tap()
            return PasswordRobot()
        }
    }
}
