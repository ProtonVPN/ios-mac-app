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
fileprivate let externamlEmailErrorDialog = "Email verification temporarily disabled"
fileprivate let nextButtonId = "SignupViewController.nextButton"
fileprivate let signInButtonId = "SignupViewController.signinButton"
fileprivate let protonmailErrorMessage = "Please use a non-ProtonMail email address"

class SignupRobot: CoreElements {
    
    public let verify = Verify()
    
    func signinButtonTap() -> LoginRobot {
        button(signInButtonId).tap()
        return LoginRobot()
    }
    
    func enterEmail(_ email: String) -> SignupRobot {
        return insertExternalEmail(email)
    }
    
    private func insertExternalEmail(_ email: String) -> SignupRobot {
        textField(externalEmailTextFieldId).tap().typeText(email)
        return self
     }
    
    func nextButtonTap<T: CoreElements>(robot _: T.Type) -> T {
        button(nextButtonId).tap()
        return T()
    }
    
    class Verify: CoreElements {

        @discardableResult
        func signupScreenIsShown() -> SignupRobot {
            staticText(titleId).wait().checkExists()
            staticText(subtitleId).wait().checkExists()
            return SignupRobot()
        }
        
        @discardableResult
        func protonmailAccountErrorIsShown() -> SignupRobot {
            textView(protonmailErrorMessage).wait().checkExists()
            button("OK").wait().checkExists().tap()
            return SignupRobot()
        }
    }
}
