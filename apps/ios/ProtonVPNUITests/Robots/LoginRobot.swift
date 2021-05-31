//
//  LoginRobot.swift
//  ProtonVPNUITests
//
//  Created by Egle Predkelyte on 2021-05-18.
//  Copyright © 2021 Proton Technologies AG. All rights reserved.
//

import PMTestAutomation

fileprivate let usernameField = "Username"
fileprivate let passwordfields = "Password"
fileprivate let loginButton = "Log In"


class LoginRobot: CoreElements {
    
    @discardableResult
    func loginUser(credentials: Credentials) -> LoginRobot {
        
        return typeUsername(username: credentials.username)
            .typePassword(password: credentials.password)
            .signIn()
    }
    
    private func typeUsername(username: String) -> LoginRobot {
        textField(usernameField).typeText(username)
        return self
    }
    
    private func typePassword(password: String) -> LoginRobot {
        secureTextField(passwordfields).tap().typeText(password)
        return self
    }
    
    private func signIn() -> LoginRobot {
        button(loginButton).tap()
        return self
    }
}
