//
//  AppSessionManagerMock.swift
//  ProtonVPN - Created on 10/09/2019.
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
import LegacyCommon
import VPNShared

@testable import ProtonVPN

class AppSessionManagerMock: AppSessionManager {
    
    init(sessionStatus: SessionStatus, loggedIn: Bool, sessionChanged: Notification.Name, vpnGateway: VpnGatewayProtocol) {
        self.sessionStatus = sessionStatus
        self.loggedIn = loggedIn
        self.sessionChanged = sessionChanged
        self.vpnGateway = vpnGateway
    }
    
    public var callbackLogIn: ((String, String, () -> Void, (Error) -> Void) -> Void)?
    public var callbackLogOut: (() -> Void)?
    public var callbackAttemptDataRefreshWithoutLogin: ((() -> Void, (Error) -> Void) -> Void)?
    public var callbackLadDataWithoutFetching: (() -> Bool)?
    public var callbackLoadDataWithoutLogin: (() -> Void)?
    public var callbackRefreshData: (() -> Void)?
    public var callbackRefreshServerLoads: (() -> Void)?
    public var callbackCanPreviewApp: (() -> Bool)?
    
    // MARK: AppSessionManager implementation
    
    var vpnGateway: VpnGatewayProtocol
    
    var sessionStatus: SessionStatus
    
    var loggedIn: Bool
    
    var sessionChanged: Notification.Name
    let dataReloaded = Notification.Name("AppSessionManagerDataReloaded")
    
    func logIn(username: String, password: String, success: @escaping () -> Void, failure: @escaping (Error) -> Void) {
        callbackLogIn?(username, password, success, failure)
    }
    
    func logOut(force: Bool, reason: String?) {
        callbackLogOut?()
    }

    func finishLogin(authCredentials: AuthCredentials) async throws {

    }
    
    func attemptSilentLogIn(completion: @escaping (Result<(), Error>) -> Void) {
        callbackAttemptDataRefreshWithoutLogin?({ completion(.success) }, { error in completion(.failure(error)) })
    }
    
    func loadDataWithoutFetching() -> Bool {
        return callbackLadDataWithoutFetching?() ?? true
    }
    
    func loadDataWithoutLogin() async throws {
        callbackLoadDataWithoutLogin?()
    }
    
    func refreshData() {
        callbackRefreshData?()
    }
    
    func refreshServerLoads() {
        callbackRefreshServerLoads?()
    }
    
    func canPreviewApp() -> Bool {
        return callbackCanPreviewApp?() ?? true
    }

    func refreshVpnAuthCertificate() async throws {
        
    }

    func refreshUserInfo() {
        
    }
}
