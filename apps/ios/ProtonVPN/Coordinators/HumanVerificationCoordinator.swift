//
//  HumanVerificationCoordinator.swift
//  ProtonVPN - Created on 20/09/2019.
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

protocol HumanVerificationCoordinatorFactory {
    func makeHumanVerificationCoordinator(verificationMethods: VerificationMethods?, startingErrorMessage: String?, success: @escaping ((HumanVerificationToken) -> Void), failure: @escaping ((Error) -> Void)) -> HumanVerificationCoordinator
}

extension DependencyContainer: HumanVerificationCoordinatorFactory {
    func makeHumanVerificationCoordinator(verificationMethods: VerificationMethods?, startingErrorMessage: String?, success: @escaping ((HumanVerificationToken) -> Void), failure: @escaping ((Error) -> Void)) -> HumanVerificationCoordinator {
        return HumanVerificationCoordinatorImplementation(factory: self, verificationMethods: verificationMethods, startingErrorMessage: startingErrorMessage, success: success, failure: failure)
    }
}

protocol HumanVerificationCoordinator: Coordinator {
    var finished: (() -> Void)? { get set }
}

class HumanVerificationCoordinatorImplementation: HumanVerificationCoordinator {
    
    let success: ((HumanVerificationToken) -> Void) // Used by AlamofireWrapper.
    let failure: ((Error) -> Void)                  // Used by AlamofireWrapper.
    var finished: (() -> Void)?                     // Used by AlertService. Closes modal view.
    
    typealias Factory = HumanVerificationServiceFactory & VerificationEmailViewModelFactory & VerificationCodeViewModelFactory & VerificationSmsViewModelFactory & SmsCountryCodeViewModelFactory & LoginServiceFactory & VerificationCaptchaViewModelFactory
    private let factory: Factory
    private lazy var humanVerificationService: HumanVerificationService = factory.makeHumanVerificationService()
    private lazy var loginService: LoginService = factory.makeLoginService()
    
    private let verificationMethods: VerificationMethods?
    private let startingErrorMessage: String?
    
    init(factory: Factory, verificationMethods: VerificationMethods?, startingErrorMessage: String?, success: @escaping ((HumanVerificationToken) -> Void), failure: @escaping ((Error) -> Void)) {
        self.factory = factory
        self.verificationMethods = verificationMethods
        self.startingErrorMessage = startingErrorMessage
        self.success = success
        self.failure = failure
    }
    
    func start() {                
        let viewModel = HumanVerificationOptionsViewModel(verificationMethods: verificationMethods, errorMessage: startingErrorMessage)
        viewModel.typeSelected = { type in
            self.selectedToken(type: type)
        }
        viewModel.cancelled = {
            self.cancel()            
        }
        humanVerificationService.presentHumanVerificationOptionsViewController(viewModel: viewModel)
    }
    
    func cancel() {
        failure(UserError.cancelled)
        finished?()
    }
    
    // MARK: - Private
    
    private func selectedToken(type: HumanVerificationToken.TokenType) {
        switch type {
        case .email:
            startEmailVerification()
        case .sms:
            startSmsVerification()
        case .captcha:
            startCaptchaVerification()
        case .invite:
            SafariService.openLink(url: CoreAppConstants.ProtonVpnLinks.supportForm)
        case .payment:
            fatalError("not implemented")
        }
    }
    
    // MARK: Email verification
    
    /// Email verification step 1
    private func startEmailVerification() {
        let viewModel = factory.makeVerificationEmailViewModel()
        viewModel.codeSent = { email in
            self.getEmailCodeVerification(email: email)
        }
        viewModel.switchToLoginWithProtonMailAddress = {            
            self.finished?()
            self.loginService.presentLogin(dismissible: true, username: nil, errorMessage: LocalizedString.errorSignupUsingProtonMailAddress)
        }
        humanVerificationService.presentVerificationEmail(viewModel: viewModel)
    }
    
    /// Email verification step 2
    private func getEmailCodeVerification(email: String) {
        let viewModel = factory.makeVerificationCodeViewModel(address: email, tokenType: .email)
        viewModel.tokenReceived = { token in
            self.success(token)
            self.finished?()
        }
        viewModel.errorReceived = { error in
            self.failure(error)
            self.finished?()
        }
        viewModel.chooseAnotherMethod = {
            self.humanVerificationService.goBackToHumanVerificationOptionsViewController()
        }
        humanVerificationService.presentVerificationCode(viewModel: viewModel)
    }
        
    // MARK: SMS verification
    
    /// SMS verification step 1
    private func startSmsVerification() {
        let viewModel = factory.makeVerificationSmsViewModel()
        viewModel.codeSent = { number in
            self.getSmsCodeVerification(number: number)
        }
        viewModel.countryCodeChangeRequested = { callback in
            self.startCountryCodeSelection(with: callback)
        }
        humanVerificationService.presentVerificationSms(viewModel: viewModel)
    }
    
    /// SMS verification step 2
    private func getSmsCodeVerification(number: String) {
        let viewModel = factory.makeVerificationCodeViewModel(address: number, tokenType: .sms)
        viewModel.tokenReceived = { token in
            self.success(token)
            self.finished?()
        }
        viewModel.errorReceived = { error in
            self.failure(error)
            self.finished?()
        }
        viewModel.chooseAnotherMethod = {
            self.humanVerificationService.goBackToHumanVerificationOptionsViewController()
        }
        humanVerificationService.presentVerificationCode(viewModel: viewModel)
    }
    
    /// SMS phone country code selection
    private func startCountryCodeSelection(with callback: @escaping (PhoneCountryCode) -> Void) {
        let viewModel = factory.makeSmsCountryCodeViewModel(with: callback)
        humanVerificationService.presentSmsCountryCodeViewController(viewModel: viewModel)
    }
    
    // MARK: Captcha verification

    /// Captcha verification only step
    private func startCaptchaVerification() {
        let token = verificationMethods?.captchaToken ?? ""
        let viewModel = factory.makeVerificationCaptchaViewModel(token: token)
        
        viewModel.tokenReceived = { token in
            self.success(token)
            self.finished?()
        }
        humanVerificationService.presentVerificationCaptcha(viewModel: viewModel)
    }
    
}
