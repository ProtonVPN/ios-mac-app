//
//  Created on 4/11/24.
//
//  Copyright (c) 2024 Proton AG
//
//  ProtonVPN is free software: you can redistribute it and/or modify
//  it under the terms of the GNU General Public License as published by
//  the Free Software Foundation, either version 3 of the License, or
//  (at your option) any later version.
//
//  ProtonVPN is distributed in the hope that it will be useful,
//  but WITHOUT ANY WARRANTY; without even the implied warranty of
//  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
//  GNU General Public License for more details.
//
//  You should have received a copy of the GNU General Public License
//  along with ProtonVPN.  If not, see <https://www.gnu.org/licenses/>.

import Strings
import fusion

fileprivate let captchaNextButton = Localizable.modalsCommonNext
fileprivate let humanVerificationHeader = "Human Verification"
fileprivate let resetPuzzleButton = "Reset puzzle piece"
fileprivate let retryButton = Localizable.retry

class HumanVerificationRobot: CoreElements {
    
    public let verify = Verify()
    
    @discardableResult
    func verifyCaptcha() -> HumanVerificationRobot {
        button(captchaNextButton).tap()
        return HumanVerificationRobot()
    }
    
    class Verify: CoreElements {
        
        @discardableResult
        func captchaScreenIsShown() -> HumanVerificationRobot {
            staticText(humanVerificationHeader).checkExists()
            button(resetPuzzleButton).waitUntilExists(time: 30).checkExists()
            button(captchaNextButton)
                .waitUntilExists(time: 30)
                .checkExists()
                .waitForEnabled()
                .checkEnabled()
            return HumanVerificationRobot()
        }
        
        @discardableResult
        func captchaScreenIsNotShown() -> HumanVerificationRobot {
            button(resetPuzzleButton).checkDoesNotExist()
            return HumanVerificationRobot()
        }
    }
}
