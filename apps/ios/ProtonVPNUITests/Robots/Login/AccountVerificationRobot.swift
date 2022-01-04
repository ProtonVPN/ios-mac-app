//
//  AccountVerificationRobot.swift
//  ProtonVPNUITests
//
//  Created by Egle Predkelyte on 2021-09-15.
//  Copyright © 2021 Proton Technologies AG. All rights reserved.
//

import pmtest

fileprivate let backButton = "UINavigationItem.leftBarButtonItem"
fileprivate let accountVerificationTitle = "EmailVerificationViewController.emailVerificationTitleLabel"
fileprivate let accountVerificationSubtitle = "For your security, we must verify that the address you entered belongs to you. We sent a verification code to "
fileprivate let accountVerificationTextField = "EmailVerificationViewController.verificationCodeTextField.textField"
fileprivate let didnotRecieveCodeButton = "EmailVerificationViewController.notReceivedCodeButton"
fileprivate let requestNewCodeDialogTitle = "Request new code?"
fileprivate let requestNewCodeDialogSubtitle = "Get a replacement code sent to "
fileprivate let newCodeButton = "newCodeButton"
fileprivate let cancelButton = "cancelButton"
fileprivate let nextButtonId = "Next"
fileprivate let succesMessage = "Code sent to "
fileprivate let invalidVwerifiactionCodedialog = "Invalid verification code"
fileprivate let resendButton = "resendButton"
fileprivate let changeEmailButton = "changeEmailButton"

class AccountVerificationRobot: CoreElements {

    func enterVerificationCode(_ code: String) -> AccountVerificationRobot {
        textField(accountVerificationTextField).tap().typeText(code)
        return self
    }
    
    func nextButtonTap<T: CoreElements>(robot _: T.Type) -> T {
        button(nextButtonId).tap()
        return T()
    }
    
    func requestNewCode() -> AccountVerificationRobot {
        button(newCodeButton).tap()
        return self
    }
    
    func didNotReceiveCode() -> AccountVerificationRobot {
        button(didnotRecieveCodeButton).tap()
        return self
    }
    
    func cancelRequestCode() -> AccountVerificationRobot {
        button(cancelButton).tap()
        return self
    }

    public let verify = Verify()
    
    class Verify: CoreElements {

        @discardableResult
        func accountVerificationScreenIsShown() -> AccountVerificationRobot {
            staticText(accountVerificationTitle).wait(time: 20).checkExists()
            return AccountVerificationRobot()
        }
        
        @discardableResult
        func requestNewCodeDialogIsShown(_ email: String) -> AccountVerificationRobot {
            staticText(requestNewCodeDialogTitle).wait(time: 5).checkExists()
            staticText(requestNewCodeDialogSubtitle + email + ".").wait().checkExists()
            return AccountVerificationRobot()
        }
        
        @discardableResult
        func codeVerificationErrorIsShown() -> AccountVerificationRobot {
            staticText(invalidVwerifiactionCodedialog).wait(time: 10).checkExists()
            return AccountVerificationRobot()
        }
    }
}
