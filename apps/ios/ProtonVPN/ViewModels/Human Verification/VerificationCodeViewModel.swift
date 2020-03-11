//
//  VerificationCodeViewModel.swift
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

protocol VerificationCodeViewModelFactory {
    func makeVerificationCodeViewModel(address: String, tokenType: HumanVerificationToken.TokenType) -> VerificationCodeViewModel
}

extension DependencyContainer: VerificationCodeViewModelFactory {
    func makeVerificationCodeViewModel(address: String, tokenType: HumanVerificationToken.TokenType) -> VerificationCodeViewModel {
        return VerificationCodeViewModel(address: address, tokenType: tokenType, factory: self)
    }
}

class VerificationCodeViewModel {
    
    // Callbacks for coordinator
    var tokenReceived: ((HumanVerificationToken) -> Void)?
    var errorReceived: ((Error) -> Void)?
    var chooseAnotherMethod: (() -> Void)?
    
    // Callbacks for ViewController
    var verificationButtonEnabled: ((Bool) -> Void)?
    var resendButtonStateChanged: (() -> Void)?
    
    // Factory
    typealias Factory = LoginServiceFactory & UserApiServiceFactory & CoreAlertServiceFactory
    private let factory: Factory
    
    private lazy var loginService: LoginService = factory.makeLoginService()
    private lazy var userApiService: UserApiService = factory.makeUserApiService()
    private lazy var alertService: CoreAlertService = factory.makeCoreAlertService()
    
    private let address: String
    private let tokenType: HumanVerificationToken.TokenType
    private var code: String?
    
    private let additionalLoadingTime: TimeInterval = 5
    
    enum ResendState {
        case normal
        case normalEmpty
        case noCode
        case codeSendingInProgress
    }
    
    var resendState: ResendState = .normal {
        didSet {
            resendButtonStateChanged?()
        }
    }
    
    init(address: String, tokenType: HumanVerificationToken.TokenType, factory: Factory) {
        self.address = address
        self.tokenType = tokenType
        self.factory = factory
    }
    
    func verify(code: String) {
        verificationButtonEnabled?(false)
        self.code = code
        let token = HumanVerificationToken(type: tokenType, token: code, input: address)
        userApiService.verifyCode(token: token, success: {
            self.verificationButtonEnabled?(true)
            self.tokenReceived?(token)
            
        }, failure: { (error) in
            // DEBUGGING
            self.show(error: error)
            // END
//            if let apiError = error as? ApiError {
//                switch apiError.code {
//                case ApiErrorCode.invalidHumanVerificationCode:
//                    self.alertService.push(alert: InvalidHumanVerificationCodeAlert(tryAnother: {
//                        self.chooseAnotherMethod?()
//                    }, resend: {
//                        self.resendCode(.normalEmpty)
//                    }))
//                case ApiErrorCode.apiOffline:
//                    self.show(error: error)
//                default:
//                    self.errorReceived?(error)
//                }
//                return
//            }
//
//            if error.isNetworkError {
//                self.show(error: error)
//                return
//            }
//
//            self.errorReceived?(error)
        })
    }
    
    func resendCode(_ overwriteResendCode: VerificationCodeViewModel.ResendState = .codeSendingInProgress) {
        resendState = overwriteResendCode
        userApiService.verificationCodeRequest(tokenType: tokenType, receiverAddress: address, success: { [weak self] in
            DispatchQueue.main.asyncAfter(deadline: .now() + (self?.additionalLoadingTime ?? 0)) {
                self?.resendState = .normal
                self?.verificationButtonEnabled?(true)
                self?.alertService.push(alert: SuccessNotificationAlert(message: LocalizedString.resendSuccess))
            }
        }, failure: { [weak self] (error) in
            PMLog.ET(error.localizedDescription)
            self?.resendState = .normal
            self?.verificationButtonEnabled?(true)
            self?.alertService.push(alert: ErrorNotificationAlert(error: error))
        })
    }
    
    func noCodeReceived() {
        resendState = .noCode
    }
    
    private func show(error: Error) {
        DispatchQueue.main.async {
            self.verificationButtonEnabled?(true)
            // DEBUG
            let text: String
            if let apiError = error as? ApiError, let body = apiError.responseBody {
                text = String(format: "%@ %@", error.localizedDescription, body)
            } else {
                text = error.localizedDescription
            }
            // END
            PMLog.ET(text)
            self.alertService.push(alert: ErrorNotificationAlert(error: error))
        }
    }
    
}
