//
//  SignUpFormViewModel.swift
//  ProtonVPN - Created on 11/09/2019.
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
import DeviceCheck

protocol SignUpFormViewModelFactory {
    func makeSignUpFormViewModel(plan: AccountPlan) -> SignUpFormViewModel
}

extension DependencyContainer: SignUpFormViewModelFactory {
    func makeSignUpFormViewModel(plan: AccountPlan) -> SignUpFormViewModel {
        return SignUpFormViewModelImplementation(factory: self, plan: plan)
    }
}

protocol SignUpFormViewModel {
    
    // Callbacks
    var formDataChanged: (() -> Void)? { get set }
    var showError: ((Error) -> Void)? { get set }
    var registrationFinished: ((_ loggedIn: Bool) -> Void)? { get set }
    var registrationCancelled: (() -> Void)? { get set }
    var loginRequested: (() -> Void)? { get set }
    
    var email: String? { get set }
    var username: String? { get set }
    var password1: String? { get set }
    var password2: String? { get set }
    
    var isLoading: Bool { get set }
    var loadingStateChanged: ((Bool) -> Void)? { get set }
    
    var isEnoughData: Bool { get }
    
    func validateEmail() -> FormValidationError?
    func validateUserName() -> FormValidationError?
    func validatePassword1() -> FormValidationError?
    func validatePassword2() -> FormValidationError?
    
    func startRegistration()
    func switchToLogin()
}

class SignUpFormViewModelImplementation: SignUpFormViewModel {
    
    // Callbacks
    var formDataChanged: (() -> Void)?
    var showError: ((Error) -> Void)?
    var registrationFinished: ((_ loggedIn: Bool) -> Void)?
    var registrationCancelled: (() -> Void)?
    var loginRequested: (() -> Void)?
    
    // User input
    var email: String? {
        didSet {
            signinInfoContainer.email = email
            formDataChanged?()
        }
    }
    var username: String? { didSet { formDataChanged?() } }
    var password1: String? { didSet { formDataChanged?() } }
    var password2: String? { didSet { formDataChanged?() } }
    
    // Services
    private lazy var userApiService: UserApiService = factory.makeUserApiService()
    private lazy var authApiService: AuthApiService = factory.makeAuthApiService()
    private lazy var paymentsService: PaymentsApiService = factory.makePaymentsApiService()
    private lazy var alertService: AlertService = factory.makeCoreAlertService()
    private lazy var appSessionManager: AppSessionManager = factory.makeAppSessionManager()
    private lazy var storeKitManager: StoreKitManager = factory.makeStoreKitManager()
    private lazy var alamofireWrapper: AlamofireWrapper = factory.makeAlamofireWrapper()
    private lazy var userPropertiesCreator: UserPropertiesCreator = factory.makeUserPropertiesCreator()
    private lazy var signinInfoContainer: SigninInfoContainer = factory.makeSigninInfoContainer()
    
    // Factory
    typealias Factory = UserApiServiceFactory & AuthApiServiceFactory & AppSessionManagerFactory & StoreKitManagerFactory & PaymentsApiServiceFactory & CoreAlertServiceFactory & AlamofireWrapperFactory & UserPropertiesCreatorFactory & SigninInfoContainerFactory
    private let factory: Factory
    
    private let plan: AccountPlan
    private var paymentVerificationCode: String? {
        didSet {
            let token: HumanVerificationToken? // = TokenType.payment(paymentVerificationCode ?? "")
            if let paymentVerificationCode = paymentVerificationCode {
                token = HumanVerificationToken(type: .payment, token: paymentVerificationCode)
            } else {
                token = nil
            }            
            alamofireWrapper.setHumanVerification(token: token)
        }
    }
    
    init(factory: Factory, plan: AccountPlan) {
        self.factory = factory
        self.plan = plan
    }
    
    deinit {
        signinInfoContainer.email = nil
    }
    
    // Loading indicator
    var isLoading = false { didSet { DispatchQueue.main.async { self.loadingStateChanged?(self.isLoading) } } }
    var loadingStateChanged: ((Bool) -> Void)?
    
    var isEnoughData: Bool {
        return email != nil && username != nil && password1 != nil && password2 != nil
            && !(email?.isEmpty ?? false)
            && !(username?.isEmpty ?? false)
            && !(password1?.isEmpty ?? false)
            && !(password2?.isEmpty ?? false)
    }
    
    func switchToLogin() {
        loginRequested?()
    }
    
    func cancel() {
        registrationCancelled?()
    }
    
    // MARK: Validation
    
    func validateEmail() -> FormValidationError? {
        guard !email.isEmpty else { return FormValidationError.emptyValue }
        return email.isEmail ? nil : FormValidationError.wrongEmail
    }
    
    func validateUserName() -> FormValidationError? {
        return username.isEmpty ? FormValidationError.emptyValue : nil
    }
    
    func validatePassword1() -> FormValidationError? {
        guard !password1.isEmpty else { return FormValidationError.emptyValue }
        return password1.elementsEqual(password2) ? nil : FormValidationError.passwordsDontMatch
    }
    
    func validatePassword2() -> FormValidationError? {
        guard !password2.isEmpty else { return FormValidationError.emptyValue }
        return password1.elementsEqual(password2) ? nil : FormValidationError.passwordsDontMatch
    }
    
    func startRegistration() {
        isLoading = true
        step1checkUsername()
    }
    
    // MARK: Private
    
    private func finishedSuccessfully(loggedIn: Bool) {
        isLoading = false
        registrationFinished?(loggedIn)
    }
    
    private func failed(withError error: Error?) {
        isLoading = false
        paymentVerificationCode = nil
        if let error = error {
            DispatchQueue.main.async {
                self.showError?(error)
            }
        }
    }
    
    private func step1checkUsername() {
        guard let username = username else { return }
        userApiService.checkAvailability(username: username, success: { [weak self] in
            self?.step2Pay()
        }, failure: { [weak self] error in
            self?.failed(withError: error)
        })
    }
    
    private func step2Pay() {
        guard plan.paid, let productId = plan.storeKitProductId else {
            self.step3modulus()
            return
        }
        
        storeKitManager.subscribeToPaymentQueue()
        storeKitManager.purchaseProduct(withId: productId, refreshHandler: { [weak self] in
            self?.failed(withError: nil)
            
        }, successCompletion: { [weak self] verificationCode in
            PMLog.ET("IAP succeeded", level: .info)
            self?.paymentVerificationCode = verificationCode
            self?.step3modulus()
            
        }, errorCompletion: { [weak self] (error) in
            PMLog.ET("IAP errored: \(error.localizedDescription)")
            self?.failed(withError: error)
                
        }, deferredCompletion: {
            PMLog.ET("IAP deferred", level: .warn)
            
        })
    }
        
    private func step3modulus() {
        authApiService.modulus(success: { [weak self] (modulusResponse) in
            self?.step4getDeviceToken(modulusResponse: modulusResponse)
        }, failure: { [weak self] (error) in
            PMLog.ET("Modulus call failed with error: \(error)")
            self?.failed(withError: error)
        })
    }
    
    private func step4getDeviceToken(modulusResponse: ModulusResponse) {
        guard #available(iOS 11.0, *) else {
            step5CreateUser(modulusResponse: modulusResponse, deviceToken: nil)
            return
        }
        
        let curDevice = DCDevice.current
        guard curDevice.isSupported else {
            step5CreateUser(modulusResponse: modulusResponse, deviceToken: nil)
            return
        }
        curDevice.generateToken(completionHandler: { [weak self] (data, error) in
            self?.step5CreateUser(modulusResponse: modulusResponse, deviceToken: data)
        })
    }
    
    private func step5CreateUser(modulusResponse: ModulusResponse, deviceToken: Data?) {
        guard let password = self.password1, let username = self.username, let email = email else { return }
        
        do {
            let userProperties = try userPropertiesCreator.createUserProperties(email: email, username: username, password: password, modulusResponse: modulusResponse, deviceToken: deviceToken)
            
            self.userApiService.createUser(userProperties: userProperties, success: { [weak self] in
                self?.step6login()
            }, failure: { [weak self] (error) in
                self?.failed(withError: error)
            })
        } catch {
            PMLog.ET("Modulus creation failed")
            failed(withError: error)
        }
    }
    
    private func step6login() {
        guard let password = self.password1, let username = self.username else { return }
        
        // login
        appSessionManager.logIn(username: username, password: password, success: { [weak self] in
            self?.finishedSuccessfully(loggedIn: true)
        }, failure: { [weak self] (_) in
            self?.finishedSuccessfully(loggedIn: false)
        })
    }
    
}
