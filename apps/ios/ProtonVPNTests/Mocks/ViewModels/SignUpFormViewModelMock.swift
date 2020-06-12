//
//  SignUpFormViewModelMock.swift
//  ProtonVPN - Created on 14/10/2019.
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

import vpncore

class SignUpFormViewModelMock: SignUpFormViewModel {
    
    var resultValidateEmail: FormValidationError?
    var resultvalidateUserName: FormValidationError?
    var resultvalidatePassword1: FormValidationError?
    var resultvalidatePassword2: FormValidationError?
    
    // MARK: SignUpFormViewModel implementation
    
    var formDataChanged: (() -> Void)?
    var showError: ((Error) -> Void)?
    var registrationFinished: ((Bool) -> Void)?
    var registrationCancelled: (() -> Void)?
    var loginRequested: (() -> Void)?
    
    var email: String?
    var username: String?
    var password1: String?
    var password2: String?
    var isLoading: Bool = false
    
    var loadingStateChanged: ((Bool) -> Void)?
    var isEnoughData: Bool = false
    
    func validateEmail() -> FormValidationError? {
        return resultValidateEmail
    }
    
    func validateUserName() -> FormValidationError? {
        return resultvalidateUserName
    }
    
    func validatePassword1() -> FormValidationError? {
        return resultvalidatePassword1
    }
    
    func validatePassword2() -> FormValidationError? {
        return resultvalidatePassword2
    }
    
    func startRegistration() {
    }
    
    func switchToLogin() {
    }
    
    func cancel(){
    }
}
