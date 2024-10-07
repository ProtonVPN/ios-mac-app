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
import Strings
import fusion

fileprivate let fieldUsername = "UsernameTextField"
fileprivate let fieldPassword = "PasswordTextField"
fileprivate let loginButton = "LoginButton"
fileprivate let modalTitle = "Thanks for upgrading to Business/Visionary"
fileprivate let modalSubtitle = "description1Label"
fileprivate let loginAgainButton = "Sign in again"
fileprivate let assignConnectionButton = "Enable VPN connections"

class LoginRobot: CoreElements {
    
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
        return typeOnlyPassword(password: password)
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
        button(loginAgainButton).tap()
        return self
    }
    
    func isLoginScreenVisible() -> Bool {
        return textField(fieldUsername).waitUntilExists(time: 0.5).exists() && secureTextField(fieldPassword).waitUntilExists(time: 0.5).exists()
    }
    
    private func typeUsername(_ username: String) -> LoginRobot {
        textField(fieldUsername).tap().clearText().typeText(username)
        return self
    }
    
    private func typePassword(password: String) -> LoginRobot {
        secureTextField(fieldPassword).tap().clearText().typeText(password)
        return self
    }
    
    private func typeOnlyPassword(password: String) -> LoginRobot {
        textField(fieldUsername).tap().clearText().typeText("")
        secureTextField(fieldPassword).tap().clearText().typeText(password)
        return self
    }
    
    private func typeOnlyUsername(username: String) -> LoginRobot {
        textField(fieldUsername).tap().clearText().typeText(username)
        secureTextField(fieldPassword).tap().clearText().typeText("")
        return self
    }
    
    private func signIn() -> LoginRobot {
        button(loginButton).tap()
        return self
    }
    
    let verify = Verify()

    class Verify: CoreElements {
        
        @discardableResult
        func checkLoginScreenIsShown() -> LoginRobot {
            button(Localizable.createAccount).checkExists()
            textField(fieldUsername).checkExists()
            secureTextField(fieldPassword).checkExists()
            return LoginRobot()
        }
        
        @discardableResult
        func checkLoginButtonIsNotEnabled() -> LoginRobot {
            button(loginButton).checkDisabled()
            return LoginRobot()
        }
        
        @discardableResult
        func checkLoginButtonIsEnabled() -> LoginRobot {
            button(loginButton).checkEnabled()
            return LoginRobot()
        }
        
        @discardableResult
        func checkErrorMessageIsShown(message: String ) -> LoginRobot {
            staticText(message).checkExists()
            return LoginRobot()
        }
        
        @discardableResult
        func checkModalIsShown(timeout: TimeInterval = WaitTimeout.normal) -> LoginRobot {
            staticText(modalTitle).waitUntilExists(time: timeout).checkExists()
            staticText(modalSubtitle).waitUntilExists(time: timeout).checkExists()
            button(loginAgainButton).checkEnabled()
            return LoginRobot()
        }
    }
}
