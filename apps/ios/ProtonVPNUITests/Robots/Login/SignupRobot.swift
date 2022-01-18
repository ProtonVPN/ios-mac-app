//
//  NewSignupRobot.swift
//  ProtonVPNUITests
//
//  Created by Egle Predkelyte on 2021-09-01.
//  Copyright © 2021 Proton Technologies AG. All rights reserved.
//

import pmtest

fileprivate let titleId = "SignupViewController.createAccountTitleLabel"
fileprivate let subtitleId = "SignupViewController.createAccountDescriptionLabel"
fileprivate let externalEmailTextFieldId = "SignupViewController.externalEmailTextField.textField"
fileprivate let internalEmailTextFieldId = "SignupViewController.internalNameTextField.textField"
fileprivate let nextButtonId = "SignupViewController.nextButton"
fileprivate let signInButtonId = "SignupViewController.signinButton"
fileprivate let protonmailErrorMessage = "Please use a non-ProtonMail email address"
fileprivate let usernameErrorMessage = "Username already used"

class SignupRobot: CoreElements {
    
    public let verify = Verify()
    
    func signinButtonTap() -> LoginRobot {
        button(signInButtonId).tap()
        return LoginRobot()
    }
    
    func enterEmail(_ email: String) -> SignupRobot {
        return insertInternalEmail(email)
    }
    
    private func insertInternalEmail(_ email: String) -> SignupRobot {
        textField(internalEmailTextFieldId).tap().typeText(email)
        return self
     }
    
    func nextButtonTap<T: CoreElements>(robot _: T.Type) -> T {
        button(nextButtonId).tap()
        return T()
    }
    
    class Verify: CoreElements {

        @discardableResult
        func signupScreenIsShown() -> SignupRobot {
            staticText(titleId).wait(time: 10).checkExists()
            staticText(subtitleId).wait(time: 10).checkExists()
            return SignupRobot()
        }
        
        @discardableResult
        func protonmailAccountErrorIsShown() -> SignupRobot {
            textView(protonmailErrorMessage).wait(time: 10).checkExists()
            button("OK").wait().checkExists().tap()
            return SignupRobot()
        }
        
        @discardableResult
        func usernameErrorIsShown() -> SignupRobot {
            textView(usernameErrorMessage).wait(time: 2).checkExists()
            button("OK").wait().checkExists().tap()
            return SignupRobot()
        }
    }
}
