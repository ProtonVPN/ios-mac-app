//
//  SignUpOptionsViewModel.swift
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

class HumanVerificationOptionsViewModel {
    
    var cancelled: (() -> Void)?
    var typeSelected: ((HumanVerificationToken.TokenType) -> Void)?
    
    private let verificationMethods: VerificationMethods?
    private let propertiesManager: PropertiesManagerProtocol
    private var openingError: String?
    
    init(verificationMethods: VerificationMethods?, propertiesManager: PropertiesManagerProtocol, errorMessage: String?) {
        self.propertiesManager = propertiesManager
        self.verificationMethods = verificationMethods
        self.openingError = errorMessage
    }
    
    func getOpeningError() -> String? {
        guard let errorMessage = openingError else { return nil }
        
        openingError = nil
        return errorMessage
    }
    
    func showEmailOption() -> Bool {
        return verificationMethods?.email ?? false
    }
    
    func showSMSOption() -> Bool {
        return verificationMethods?.sms ?? false
    }
    
    func showInviteOption() -> Bool {
        let option = verificationMethods?.invite ?? false
        guard option else { return false }
        if !propertiesManager.humanValidationFailed { return false }
        return option
    }
    
    func showCaptchaOption() -> Bool {
        return verificationMethods?.captcha ?? false
    }
    
    func showEmailScreen() {
        typeSelected?(.email)
    }
    
    func showSmsScreen() {
        typeSelected?(.sms)
    }
    
    func contactSupport() {
        typeSelected?(.invite)
    }
    
    func showCaptchaScreen() {
        typeSelected?(.captcha)
    }
    
    func cancel() {
        cancelled?()
    }
    
}
