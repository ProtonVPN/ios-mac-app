//
//  LoginViewModel.swift
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
import UIKit
import Alamofire
import vpncore

protocol LoginViewModelDelegate: class {
    func showError(_ error: Error)
    func dismissLogin()
}

class LoginViewModel {
    
    typealias Factory = AlamofireWrapperFactory
    & PropertiesManagerFactory
    & AppSessionManagerFactory
    & AppSessionRefresherFactory
    & LoginServiceFactory
    & CoreAlertServiceFactory
    
    private let factory: Factory
    
    private lazy var propertiesManager = factory.makePropertiesManager()
    private lazy var appSessionManager: AppSessionManager = factory.makeAppSessionManager()
    private lazy var appSessionRefresher: AppSessionRefresher = factory.makeAppSessionRefresher()
    private lazy var loginService: LoginService = factory.makeLoginService()
    private lazy var alamofireWrapper: AlamofireWrapper = factory.makeAlamofireWrapper()
    public lazy var alertService: AlertService = factory.makeCoreAlertService()
    
    let dismissible: Bool
    
    // handles signup attempt with existing address
    let username: String?
    let openingError: String?
    
    let logInFailure = Notification.Name("LoginViewModelLogInFailure")
    static let logInSilentlyFailure = Notification.Name("LoginViewModelLogInFailure")
    static let logInFailureWithSupport = Notification.Name("LoginViewModelLogInFailureWithSupport")
    
    weak var delegate: LoginViewModelDelegate?
    weak var tabBarDelegate: TabBarViewModelModelDelegate?
    
    init(dismissible: Bool = true, username: String? = nil, errorMessage: String? = nil, factory: Factory) {
        self.dismissible = dismissible
        self.username = username
        self.openingError = errorMessage
        self.factory = factory
    }
    
    func logIn(username: String, password: String) {
        appSessionManager.logIn(username: username, password: password, success: { [weak self] in
            self?.loginService.presentMainInterface()
            self?.delegate?.dismissLogin()
            self?.tabBarDelegate?.removeLoginBox()
            self?.alamofireWrapper.setHumanVerification(token: nil)
        }, failure: { [weak self] error in
            self?.delegate?.showError(error)
            guard let `self` = self else { return }
            NotificationCenter.default.post(name: self.logInFailure, object: error.localizedDescription)
        })
    }

    func logInSilently() {
        if appSessionManager.loadDataWithoutFetching() {
            appSessionRefresher.refreshData()
        } else { // if no data is stored already, then show spinner and wait for data from the api
            appSessionManager.attemptDataRefreshWithoutLogin(success: { [unowned self] in
                self.loginService.presentMainInterface()
            }, failure: { [appSessionManager] error in
                appSessionManager.loadDataWithoutLogin(success: { [unowned self] in
                    self.loginService.presentOnboarding()
                }, failure: { [unowned self] _ in
                    self.loginService.presentOnboarding()
                })
            })
        }
        
        if appSessionManager.sessionStatus == .established {
            loginService.presentMainInterface()
        }
    }
    
    func signUpTapped() {
        loginService.presentSignup(dismissible: dismissible)
    }
}
