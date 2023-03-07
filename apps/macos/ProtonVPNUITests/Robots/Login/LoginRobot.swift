//
//  Created on 2022-01-11.
//
//  Copyright (c) 2022 Proton AG
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

fileprivate let fieldUsername = "UsernameTextField"
fileprivate let fieldPassword = "PasswordTextField"
fileprivate let loginButton = "LoginButton"
fileprivate let modalTitle = "Thanks for upgrading to Business/Visionary"
fileprivate let modalSubtitle = "description1Label"
fileprivate let loginAgainButton = "Login again"
fileprivate let assignConnectionButton = "Enable VPN connections"

class LoginRobot {
    
    @discardableResult
    func loginUser(credentials: Credentials) -> LoginRobot {
        return typeUsername(credentials.username)
            .typePassword(password: credentials.password)
            .signIn()
    }
    
    @discardableResult
    func withIncorrectCredentials(_ username: String, _ password: String) -> LoginRobot {
        return typeUsername(username)
            .typePassword(password: password)
            .signIn()
    }
    
    func loginAsSubuser(subusercredentials: Credentials) -> LoginRobot {
        return typeUsername(subusercredentials.username)
            .typePassword(password: subusercredentials.password)
            .signIn()
    }
        
    @discardableResult
    func withEmptyFields() -> LoginRobot {
        return self
    }

    @discardableResult
    func withEmptyPassword(_ username: String) -> LoginRobot {
        return typeOnlyUsername(username: username)
            .signIn()
    }
        
    @discardableResult
    func withEmptyUsername(_ password: String) -> LoginRobot {
        return typePassword(password: password)
            .signIn()
    }
        
    @discardableResult
    func withIncorrectUnicode(_ username: String, _ password: String) -> LoginRobot {
        return typeUsername(username)
            .typePassword(password: password)
            .signIn()
    }
        
    @discardableResult
    func clickLoginAgain() -> LoginRobot {
        app.buttons[loginAgainButton].click()
        return LoginRobot()
    }
    
    private func typeUsername(_ username: String) -> LoginRobot {
        app.textFields[fieldUsername].click()
        app.textFields[fieldUsername].clearAndEnterText(text: username)
        return self
    }
    
    private func typePassword(password: String) -> LoginRobot {
        app.secureTextFields[fieldPassword].click()
        app.secureTextFields[fieldPassword].clearAndEnterText(text: password)
        return self
    }
    
    private func typeOnlyPassword(password: String) -> LoginRobot {
        app.textFields[fieldUsername].clearAndEnterText(text: "")
        app.secureTextFields[fieldPassword].click()
        app.secureTextFields[fieldPassword].clearAndEnterText(text: password)
        return self
    }
    
    private func typeOnlyUsername(username: String) -> LoginRobot {
        app.textFields[fieldUsername].clearAndEnterText(text: username)
        app.secureTextFields[fieldPassword].click()
        app.secureTextFields[fieldPassword].clearAndEnterText(text: "")
        return self
    }
    
    private func signIn() -> LoginRobot {
        app.buttons[loginButton].click()
        return self
    }
    
    let verify = Verify()

    class Verify {
        
        @discardableResult
        func checkLoginButtonIsNotEnabled() -> LoginRobot {
            XCTAssertFalse(app.buttons[loginButton].isEnabled)
            return LoginRobot()
        }
        
        @discardableResult
        func checkLoginButtonIsEnabled() -> LoginRobot {
            XCTAssert(app.buttons[loginButton].isEnabled)
            return LoginRobot()
        }
        
        @discardableResult
        func checkErrorMessageIsShown(message: String ) -> LoginRobot {
            XCTAssert(app.staticTexts[message].waitForExistence(timeout: 5))
            return LoginRobot()
        }
        
        @discardableResult
        func checkModalIsShown(timeout: TimeInterval = 5) -> LoginRobot {
            XCTAssert(app.staticTexts[modalTitle].waitForExistence(timeout: timeout))
            XCTAssert(app.staticTexts[modalSubtitle].waitForExistence(timeout: timeout))
            XCTAssert(app.buttons[loginAgainButton].isEnabled)
            return LoginRobot()
        }
    }
}
