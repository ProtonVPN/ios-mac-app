//
//  LoginService.swift
//  ProtonVPN - Created on 01.07.19.
//
//  Copyright (c) 2019 Proton Technologies AG
//
//  This file is part of ProtonVPN.
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
//

import Foundation
import vpncore

class LoginServiceMock: LoginService {
    
    public var callbackPresentRegistrationForm: ((SignUpFormViewModel) -> Void)?
    public var callbackPresentLogin: ((Bool, String?, String?) -> Void)?
    public var callbackPresentSignup: ((Bool) -> Void)?
    public var callbackPresentOnboarding: (() -> Void)?
    public var callbackMainInterface: (() -> Void)?
    
    // MARK: -
    
    func presentRegistrationForm(viewModel: SignUpFormViewModel) {
        callbackPresentRegistrationForm?(viewModel)
    }
    
    func presentLogin(dismissible: Bool, username: String?, errorMessage: String?) {
        callbackPresentLogin?(dismissible, username, errorMessage)
    }
    
    func presentLogin(dismissible: Bool) {
        callbackPresentLogin?(dismissible, nil, nil)
    }
    
    func presentLogin() {
        callbackPresentLogin?(true, nil, nil)
    }
    
    func presentSignup(dismissible: Bool) {
        callbackPresentSignup?(dismissible)
    }
    
    func presentSignup() {
        callbackPresentSignup?(true)
    }
    
    func presentOnboarding() {
        callbackPresentOnboarding?()
    }
    
    func presentMainInterface() {
        callbackMainInterface?()
    }
        
}
