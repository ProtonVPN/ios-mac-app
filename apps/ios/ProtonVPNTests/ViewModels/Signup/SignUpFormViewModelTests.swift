//
//  SignUpFormViewModelTests.swift
//  ProtonVPN - Created on 13/09/2019.
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

import XCTest
import vpncore

class SignUpFormViewModelTests: XCTestCase {

    private var appSessionManager: AppSessionManagerMock!
    private var userApiService: UserApiServiceMock!
    private var authApiService: AuthApiServiceMock!
    private var paymentApiService: PaymentsApiServiceMock!
    private var alertService: CoreAlertServiceMock!
    private var factory: Factory!
    private var viewModel: SignUpFormViewModel!
    private var alamofireWrapper: AlamofireWrapper!
    private var storeKitManagerMock: StoreKitManagerMock!
    
    override func setUp() {
        appSessionManager = AppSessionManagerMock(sessionStatus: .notEstablished, loggedIn: false, sessionChanged: Notification.Name("sessionChanged"))
        userApiService = UserApiServiceMock()
        authApiService = AuthApiServiceMock()
        paymentApiService = PaymentsApiServiceMock()
        alertService = CoreAlertServiceMock()
        alamofireWrapper = AlamofireWrapperMock()
        storeKitManagerMock = StoreKitManagerMock()
        
        factory = Factory(appSessionManager: appSessionManager, userApiService: userApiService, authApiService: authApiService, storeKitManager: storeKitManagerMock, paymentsApiService: paymentApiService, coreAlertService: alertService, alamofireWrapper: alamofireWrapper, userPropertiesCreator: UserPropertiesCreatorMock(), signinInfoContainer: SigninInfoContainer())
        viewModel = SignUpFormViewModelImplementation(factory: factory, plan: AccountPlan.free)
    }

    override func tearDown() {
    }

    func testValidatesEmptyFields() {
        XCTAssertEqual(FormValidationError.emptyValue, viewModel.validateUserName())
        XCTAssertEqual(FormValidationError.emptyValue, viewModel.validateEmail())
        XCTAssertEqual(FormValidationError.emptyValue, viewModel.validatePassword1())
        XCTAssertEqual(FormValidationError.emptyValue, viewModel.validatePassword2())
        
        viewModel.username = "abc"
        XCTAssertNotEqual(FormValidationError.emptyValue, viewModel.validateUserName())
        viewModel.email = "abc"
        XCTAssertNotEqual(FormValidationError.emptyValue, viewModel.validateEmail())
        viewModel.password1 = "abc"
        XCTAssertNotEqual(FormValidationError.emptyValue, viewModel.validatePassword1())
        viewModel.password2 = "abc"
        XCTAssertNotEqual(FormValidationError.emptyValue, viewModel.validatePassword2())
    }
    
    func testValidatesEmailField() {
        viewModel.email = "abc"
        XCTAssertEqual(FormValidationError.wrongEmail, viewModel.validateEmail())
        viewModel.email = "abc@domain.com"
        XCTAssertNil(viewModel.validateEmail())
    }
    
    func testValidatesPasswordFields() {
        viewModel.password1 = "abc"
        XCTAssertEqual(FormValidationError.passwordsDontMatch, viewModel.validatePassword1())
        XCTAssertEqual(FormValidationError.emptyValue, viewModel.validatePassword2())
        
        viewModel.password2 = "abcabc"
        XCTAssertEqual(FormValidationError.passwordsDontMatch, viewModel.validatePassword1())
        XCTAssertEqual(FormValidationError.passwordsDontMatch, viewModel.validatePassword2())
        
        viewModel.password2 = "abc"
        XCTAssertNil(viewModel.validatePassword1())
        XCTAssertNil(viewModel.validatePassword2())
    }
    
    func testDisablesButtonFields() {
        XCTAssertFalse(viewModel.isEnoughData)
        viewModel.email = "abc"
        XCTAssertFalse(viewModel.isEnoughData)
        viewModel.username = "abc"
        XCTAssertFalse(viewModel.isEnoughData)
        viewModel.password1 = "abc"
        XCTAssertFalse(viewModel.isEnoughData)
        viewModel.password2 = "abc"
        XCTAssertTrue(viewModel.isEnoughData)
    }
    
    func testRegistrationWithUnavailableUsername() {
        let expectationError = XCTestExpectation(description: "Error shown")
        let expectationSuccess = XCTestExpectation(description: "Registration successful")
        expectationSuccess.isInverted = true
        
        viewModel.email = "abc"
        viewModel.username = "abc"
        viewModel.password1 = "abc"
        viewModel.password2 = "abc"
        
        userApiService.callbackcheckAvailability = { username, success, failure in
            failure(ApiError.unknownError)
        }
        viewModel.registrationFinished = { loggedIn in
            expectationSuccess.fulfill()
        }
        viewModel.showError = { error in
            expectationError.fulfill()
        }
        viewModel.startRegistration()
        
        wait(for: [expectationError, expectationSuccess], timeout: 0.02)
    }
    
    func testRegistrationSuccess() {
        let expectationError = XCTestExpectation(description: "Error shown", inverted: true)
        let expectationSuccess = XCTestExpectation(description: "Registration successful")
        let expectationPurchaseProductAPICalled = XCTestExpectation(description: "Product purchase API endpoint called", inverted: true) // We have free plan, so purchase should not be called
        let expectationModulusCalled = XCTestExpectation(description: "Modulus called")
        let expectationCreateUserCalled = XCTestExpectation(description: "Create user API endpoint called")
        let expectationLoginCalled = XCTestExpectation(description: "Log in API endpoint called")
        
        viewModel.email = "abc@abc.abc"
        viewModel.username = "abc"
        viewModel.password1 = "abcaaa"
        viewModel.password2 = "abcaaa"
        
        userApiService.callbackcheckAvailability = { username, success, failure in
            success()
        }
        storeKitManagerMock.callbackPurchaseProduct = { id, successCompletion, errorCompletion, deferredCompletion in
            expectationPurchaseProductAPICalled.fulfill()
        }
        authApiService.callbackmodulus = { success, failure in
            expectationModulusCalled.fulfill()
            success(try! ModulusResponse(dic: ["Modulus": "abc" as AnyObject, "ModulusID": "qwe" as AnyObject]))
        }
        userApiService.callbackcreateUser = { userProperties, success, failure in
            expectationCreateUserCalled.fulfill()
            success()
        }
        appSessionManager.callbackLogIn = { username, password, success, failure in
            expectationLoginCalled.fulfill()
            success()
        }
        
        viewModel.showError = { error in
            expectationError.fulfill()
        }
        viewModel.registrationFinished = { loggedIn in
            expectationSuccess.fulfill()
        }
        viewModel.startRegistration()
        
        wait(for: [expectationError, expectationSuccess, expectationPurchaseProductAPICalled, expectationModulusCalled, expectationCreateUserCalled, expectationLoginCalled], timeout: 0.2)
    }
    
}

fileprivate class Factory: SignUpFormViewModelImplementation.Factory {
    
    var appSessionManager: AppSessionManager
    var userApiService: UserApiService
    var authApiService: AuthApiService
    var storeKitManager: StoreKitManager
    var paymentsApiService: PaymentsApiService
    var coreAlertService: CoreAlertService
    var alamofireWrapper: AlamofireWrapper
    var userPropertiesCreator: UserPropertiesCreator
    var signinInfoContainer: SigninInfoContainer
    
    init(appSessionManager: AppSessionManager, userApiService: UserApiService, authApiService: AuthApiService, storeKitManager: StoreKitManager, paymentsApiService: PaymentsApiService, coreAlertService: CoreAlertService, alamofireWrapper: AlamofireWrapper, userPropertiesCreator: UserPropertiesCreator, signinInfoContainer: SigninInfoContainer) {
        self.appSessionManager = appSessionManager
        self.userApiService = userApiService
        self.authApiService = authApiService
        self.storeKitManager = storeKitManager
        self.paymentsApiService = paymentsApiService
        self.coreAlertService = coreAlertService
        self.alamofireWrapper = alamofireWrapper
        self.userPropertiesCreator = userPropertiesCreator
        self.signinInfoContainer = signinInfoContainer
    }
    
    func makeAppSessionManager() -> AppSessionManager {
        return appSessionManager
    }
    
    func makeUserApiService() -> UserApiService {
        return userApiService
    }
    
    func makeAuthApiService() -> AuthApiService {
        return authApiService
    }
        
    func makeStoreKitManager() -> StoreKitManager {
        return storeKitManager
    }
    
    func makePaymentsApiService() -> PaymentsApiService {
        return paymentsApiService
    }
    
    func makeCoreAlertService() -> CoreAlertService {
        return coreAlertService
    }
    
    func makeAlamofireWrapper() -> AlamofireWrapper {
        return alamofireWrapper
    }
    
    func makeUserPropertiesCreator() -> UserPropertiesCreator {
        return userPropertiesCreator
    }
    
    func makeSigninInfoContainer() -> SigninInfoContainer {
        return signinInfoContainer
    }
}
