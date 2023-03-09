//
//  AccountVerificationRobot.swift
//  ProtonVPNUITests
//
//  Created by Egle Predkelyte on 2021-09-15.
//  Copyright © 2021 Proton Technologies AG. All rights reserved.
//

import fusion

fileprivate let accountVerificationTitle = "EmailVerificationViewController.emailVerificationTitleLabel"
fileprivate let accountVerificationTextField = "EmailVerificationViewController.verificationCodeTextField.textField"
fileprivate let nextButtonId = "Next"

class AccountVerificationRobot: CoreElements {

    func enterVerificationCode(_ code: String) -> AccountVerificationRobot {
        textField(accountVerificationTextField).tap().typeText(code)
        return self
    }
    
    func nextButtonTap<T: CoreElements>(robot _: T.Type) -> T {
        button(nextButtonId).tap()
        return T()
    }

    public let verify = Verify()
    
    class Verify: CoreElements {

        @discardableResult
        func accountVerificationScreenIsShown() -> AccountVerificationRobot {
            staticText(accountVerificationTitle).wait(time: 20).checkExists()
            return AccountVerificationRobot()
        }
    }
}
