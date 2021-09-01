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
fileprivate let nextButton = "SignupViewController.nextButton"
fileprivate let signInButtonId = "SignupViewController.signinButton"
fileprivate let protonmailErrorMessage = "Please use a non-ProtonMail email address"

class NewSignupRobot: CoreElements {
    
    func signinButtonTap() -> NewLoginRobot {
        button(signInButtonId).tap()
        return NewLoginRobot()
    }
    
    func protonmailAccountNotAvailable(_ email: String) -> NewSignupRobot {
        return insertExternalEmail(email)
            .nextVerificationStep()
    }
    
    private func insertExternalEmail(_ email: String) -> NewSignupRobot {
         textField(externalEmailTextFieldId).tap().typeText(email)
         return self
     }
    
    private func nextVerificationStep() -> NewSignupRobot {
        button(nextButton).tap()
         return self
     }

    
    public let verify = Verify()
    
    class Verify: CoreElements {

        @discardableResult
        func signupScreenIsShown() -> NewSignupRobot {
            staticText(titleId).wait().checkExists()
            staticText(subtitleId).wait().checkExists()
            return NewSignupRobot()
        }
        
        @discardableResult
        func protonmailAccountErrorIsShown() -> NewSignupRobot {
            staticText(protonmailErrorMessage).wait().checkExists()
            return NewSignupRobot()
        }

    }
}

