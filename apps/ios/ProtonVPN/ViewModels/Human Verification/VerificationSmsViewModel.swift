//
//  SignUpSmsViewModel.swift
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

import UIKit
import vpncore

protocol VerificationSmsViewModelFactory {
    func makeVerificationSmsViewModel() -> VerificationSmsViewModel
}

extension DependencyContainer: VerificationSmsViewModelFactory {
    func makeVerificationSmsViewModel() -> VerificationSmsViewModel {
        return VerificationSmsViewModel(factory: self)
    }
}

class VerificationSmsViewModel {
    
    // Callbacks for coordinator
    var codeSent: ((String) -> Void)?
    var countryCodeChangeRequested: ((_ selectionCallback: @escaping (PhoneCountryCode) -> Void) -> Void)?
    
    // Callbacks for ViewController
    var verificationButtonEnabled: ((Bool) -> Void)?
    var codeChanged: (() -> Void)?
    
    // Factory
    typealias Factory = LoginServiceFactory & UserApiServiceFactory & CoreAlertServiceFactory & PropertiesManagerFactory
    private let factory: Factory
    
    private lazy var loginService: LoginService = factory.makeLoginService()
    private lazy var userApiService: UserApiService = factory.makeUserApiService()
    private lazy var alertService: CoreAlertService = factory.makeCoreAlertService()
    private lazy var propertiesManager: PropertiesManagerProtocol = factory.makePropertiesManager()
              
    var code = "+1" {
        didSet {
            codeChanged?()
        }
    }
    var phone = ""
    
    private var tokenType: HumanVerificationToken.TokenType {
        return .sms
    }
    
    private var tokenAddress: String {
        return "\(code)\(phone)"
    }
    
    init(factory: Factory) {
        self.factory = factory
    }
    
    func showCountryCodeScreen() {
        countryCodeChangeRequested?({ [weak self] (phoneCountryCode) in
            self?.code = "+\(phoneCountryCode.phoneCode)"
        })
    }
    
    func verifyEnabled() -> Bool {
        return !phone.isEmpty
    }
    
    func verify() {
        verificationButtonEnabled?(false)
                
        userApiService.verificationCodeRequest(tokenType: tokenType, receiverAddress: tokenAddress, success: { [weak self] in
            guard let `self` = self else { return }
            self.verificationButtonEnabled?(true)
            self.codeSent?(self.tokenAddress)
            
        }, failure: { [weak self] (error) in
            self?.verificationButtonEnabled?(true)
            self?.propertiesManager.humanValidationFailed = true
            self?.codeSendFailed(error: error)
        })
    }
    
    private func codeSendFailed(error: Error) {
        DispatchQueue.main.async {
            PMLog.ET(error.localizedDescription)
            self.alertService.push(alert: ErrorNotificationAlert(error: error))
        }
    }    
    
}
