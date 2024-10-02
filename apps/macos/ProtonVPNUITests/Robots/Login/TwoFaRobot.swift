//
//  Created on 2023-02-03.
//
//  Copyright (c) 2023 Proton AG
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

import Foundation
import XCTest
import fusion

fileprivate let twoFaAuthentication = "Two-factor authentication"
fileprivate let twoFaAuthenticationTextField = "twoFactorTextField"
fileprivate let authButton = "Authenticate"

class TwoFaRobot: CoreElements {
    
    @discardableResult
    func fillTwoFACode(code: String) -> MainRobot {
        textField(twoFaAuthenticationTextField).tap().typeText(code)
        button(authButton).tap()
        return MainRobot()
    }
    
    let verify = Verify()
    
    class Verify: CoreElements {
        
        @discardableResult
        func twoFaAuthenticationIsShown() -> TwoFaRobot {
            staticText(twoFaAuthentication).checkExists()
            return TwoFaRobot()
        }
    }
}
