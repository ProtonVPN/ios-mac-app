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

class LoginTests: ProtonVPNUITests {

    private let loginRobot = LoginRobot()
    
    override func setUp() {
        super.setUp()
        logoutIfNeeded()
    }
    
    func testLoginWithIncorrectCredentials() {
        let username = "wrong_username"
        let userpassword = "wrong_password"
        let errorMessage = "Incorrect login credentials. Please try again"
            
        loginRobot
            .withEmptyFields()
            .verify.checkLoginButtonIsNotEnabled()
            .withEmptyUsername(userpassword)
            .verify.checkLoginButtonIsNotEnabled()
            .withEmptyPassword(username)
            .verify.checkLoginButtonIsNotEnabled()
            .withIncorrectCredentials(username, userpassword)
            .verify.checkErrorMessageIsShown(message: errorMessage)
    }
    
    func testLoginWithIncorrectUnicodeCredentials() {
        
        let username = "ąčęėįš"
        let userpassword = "žūųšįė"
        let errorMessage = "Invalid username"
            
        loginRobot
            .withIncorrectUnicode(username, userpassword)
            .verify.checkErrorMessageIsShown(message: errorMessage)
    }
    
    func testLoginAsSubuserWithNoConnectionAssigned() {
        
        let subusercredentials = Credentials.loadFrom(plistUrl: Bundle(identifier: "ch.protonmail.vpn.ProtonVPNUITests")!.url(forResource: "subusercredentials", withExtension: "plist")!)
            
        loginRobot
            .loginAsSubuser(subusercredentials: subusercredentials[0])
            .verify.checkModalIsShown()
            .verify.checkLoginButtonIsEnabled()
            .clickLoginAgain()
            .verify.checkLoginButtonIsEnabled()
    }
    
    func testLoginWithCorrectCredentials() {

        let credentials = Credentials.loadFrom(plistUrl: Bundle(identifier: "ch.protonmail.vpn.ProtonVPNUITests")!.url(forResource: "credentials", withExtension: "plist")!)

        for credentials in credentials {
            login(withCredentials: credentials)
            logoutIfNeeded()
            app.terminate()
            app.launch()
        }
    }
}
