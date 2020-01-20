//
//  SignUpViewModel.swift
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

protocol VerificationEmailViewModelFactory {
    func makeVerificationEmailViewModel() -> VerificationEmailViewModel
}

extension DependencyContainer: VerificationEmailViewModelFactory {
    func makeVerificationEmailViewModel() -> VerificationEmailViewModel {
        return VerificationEmailViewModel(factory: self)
    }
}

class VerificationEmailViewModel {
    
    // Callbacks for coordinator
    var codeSent: ((String) -> Void)?
    var switchToLoginWithProtonMailAddress: (() -> Void)?
    
    // Callbacks for ViewController
    var verificationButtonEnabled: ((Bool) -> Void)?
    
    // Factory
    typealias Factory = LoginServiceFactory & UserApiServiceFactory & CoreAlertServiceFactory & SigninInfoContainerFactory
    private let factory: Factory
    
    private lazy var loginService: LoginService = factory.makeLoginService()
    private lazy var userApiService: UserApiService = factory.makeUserApiService()
    private lazy var alertService: CoreAlertService = factory.makeCoreAlertService()
    private lazy var signinInfoContainer: SigninInfoContainer = factory.makeSigninInfoContainer()
    
    private var email: String?
        
    init(factory: Factory) {
        self.factory = factory
    }
    
    func verify(email: String) {
        verificationButtonEnabled?(false)
        let cleanedEmailAddress = clean(emailAddress: email)
        self.email = cleanedEmailAddress
                
        userApiService.verificationCodeRequest(tokenType: .email, receiverAddress: email, success: { [weak self] in
            self?.verificationButtonEnabled?(true)
            self?.codeSent?(email)
            
        }, failure: { [weak self] (error) in
            self?.verificationButtonEnabled?(true)
            
            guard let apiError = error as? ApiError else {
                self?.codeSendFailed(error: error)
                return
            }
                    
            switch (apiError.httpStatusCode, apiError.code) {
            case (_, ApiErrorCode.signupWithProtonMailAdress):
                self?.switchToLoginWithProtonMailAddress?()
    
            default:
                self?.codeSendFailed(error: error)
            }
        })
    }
    
    func getEmail() -> String? {
        return signinInfoContainer.email
    }
            
    // MARK: - Private
    
    private func clean(emailAddress: String) -> String {
        return emailAddress.trimmingCharacters(in: .whitespacesAndNewlines)
    }
    
    private func codeSendFailed(error: Error) {
        DispatchQueue.main.async {
            PMLog.ET(error.localizedDescription)
            self.alertService.push(alert: ErrorNotificationAlert(error: error))
        }
    }
    
}
