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

    private let propertiesManager = PropertiesManager()
    private let appSessionManager: AppSessionManager
    private let appSessionRefresher: AppSessionRefresher
    private let loginService: LoginService
    var alertService: AlertService
    
    let dismissible: Bool
    
    // handles signup attempt with existing address
    let username: String?
    let openingError: String?
    
    let logInFailure = Notification.Name("LoginViewModelLogInFailure")
    static let logInSilentlyFailure = Notification.Name("LoginViewModelLogInFailure")
    static let logInFailureWithSupport = Notification.Name("LoginViewModelLogInFailureWithSupport")
    
    weak var delegate: LoginViewModelDelegate?
    weak var tabBarDelegate: TabBarViewModelModelDelegate?
    
    init(dismissible: Bool = true, username: String? = nil, errorMessage: String? = nil, appSessionManager: AppSessionManager, loginService: LoginService, alertService: AlertService, appSessionRefresher: AppSessionRefresher) {
        self.dismissible = dismissible
        self.username = username
        self.openingError = errorMessage
        self.appSessionManager = appSessionManager
        self.loginService = loginService
        self.alertService = alertService
        self.appSessionRefresher = appSessionRefresher
    }
    
    func logIn(username: String, password: String) {
        appSessionManager.logIn(username: username, password: password, success: { [weak self] in
            self?.loginService.presentMainInterface()
            self?.delegate?.dismissLogin()
            self?.tabBarDelegate?.removeLoginBox()
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
