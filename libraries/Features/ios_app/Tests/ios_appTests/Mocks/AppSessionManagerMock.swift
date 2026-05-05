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
@testable import ios_app
import LegacyCommon
import VPNShared

class AppSessionManagerMock: AppSessionManager {
    init(sessionStatus: SessionStatus, loggedIn: Bool, sessionChanged: Notification.Name, vpnGateway: VpnGatewayProtocol) {
        self.sessionStatus = sessionStatus
        self.loggedIn = loggedIn
        self.sessionChanged = sessionChanged
        self.vpnGateway = vpnGateway
    }

    var callbackLogIn: ((String, String, () -> Void, (Error) -> Void) -> Void)?
    var callbackLogOut: (() -> Void)?
    var callbackAttemptDataRefreshWithoutLogin: ((() -> Void, (Error) -> Void) -> Void)?
    var callbackLadDataWithoutFetching: (() -> Bool)?
    var callbackLoadDataWithoutLogin: (() -> Void)?
    var callbackRefreshData: (() -> Void)?
    var callbackRefreshServerLoads: (() -> Void)?
    var callbackCanPreviewApp: (() -> Bool)?

    // MARK: AppSessionManager implementation

    var vpnGateway: VpnGatewayProtocol

    var sessionStatus: SessionStatus

    var loggedIn: Bool

    var sessionChanged: Notification.Name
    let dataReloaded = Notification.Name("AppSessionManagerDataReloaded")

    func logIn(username: String, password: String, success: @escaping () -> Void, failure: @escaping (Error) -> Void) {
        callbackLogIn?(username, password, success, failure)
    }

    func logOut(force _: Bool, reason _: String?) {
        callbackLogOut?()
    }

    func finishLogin(authCredentials _: AuthCredentials) async throws {}

    func attemptSilentLogIn() async throws {
        try await withCheckedThrowingContinuation { c in
            callbackAttemptDataRefreshWithoutLogin?({ c.resume(with: .success(())) }, { error in c.resume(throwing: error) })
        }
    }

    func loadDataWithoutFetching() -> Bool {
        callbackLadDataWithoutFetching?() ?? true
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
        callbackCanPreviewApp?() ?? true
    }

    func refreshVpnAuthCertificate() async throws {}

    func refreshUserInfo() {}
}
