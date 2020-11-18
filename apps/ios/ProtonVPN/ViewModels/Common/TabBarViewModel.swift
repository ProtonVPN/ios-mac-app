//
//  TabBarViewModel.swift
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
import vpncore

protocol TabBarViewModelModelDelegate: class {
    func removeLoginBox()
}

protocol TabBarViewModelDelegate: class {
    func removeLoginBox()
    func connectedQuickConnect()
    func connectingQuickConnect()
    func disconnectedQuickConnect()
}

class TabBarViewModel {
    // MARK: Properties
    let navigationService: NavigationService
    let sessionManager: AppSessionManager
    let appStateManager: AppStateManager
    let vpnGateway: VpnGatewayProtocol?
    let connectionStatusService: ConnectionStatusService
    weak var delegate: TabBarViewModelDelegate?
    
    var showLoginAnimated: Bool {
        return true
    }
    
    // MARK: Initializers
    init(navigationService: NavigationService, sessionManager: AppSessionManager, appStateManager: AppStateManager, vpnGateway: VpnGatewayProtocol?) {
        self.navigationService = navigationService
        self.sessionManager = sessionManager
        self.appStateManager = appStateManager
        self.vpnGateway = vpnGateway
        self.connectionStatusService = navigationService
        
        startObserving()
    }
    
    // MARK: Functions
    func logInTapped() {
        navigationService.presentLogin()
    }
    
    func signUpTapped() {
        navigationService.presentSignup()
    }
    
    func quickConnectTapped() {
        guard let vpnGateway = vpnGateway else {
            navigationService.presentSignup()
            return
        }
        
        if vpnGateway.connection == .disconnected || vpnGateway.connection == .disconnecting {
            vpnGateway.quickConnect()
            connectionStatusService.presentStatusViewController()
            
        } else if vpnGateway.connection == .connecting {
            vpnGateway.stopConnecting(userInitiated: true)
            
        } else {
            vpnGateway.disconnect()
        }
    }
    
    func settingShouldBeSelected() -> Bool {
        if sessionManager.loggedIn {
            return true
        } else {
            navigationService.presentLogin()
            return false
        }
    }
    
    @objc func stateChanged() {
        DispatchQueue.main.async { [weak self] in
            guard let `self` = self else { return }
            
            if self.vpnGateway?.connection == .connected {
                self.delegate?.connectedQuickConnect()
            } else if self.vpnGateway?.connection == .connecting {
                self.delegate?.connectingQuickConnect()
            } else {
                self.delegate?.disconnectedQuickConnect()
            }
        }
    }
    
    // MARK: - Private
    private func startObserving() {
        NotificationCenter.default.addObserver(self, selector: #selector(stateChanged),
                                               name: VpnGateway.connectionChanged, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(sessionChanged),
                                               name: sessionManager.sessionChanged, object: nil)
    }
    
    @objc private func sessionChanged(_ notification: Notification) {
        if sessionManager.sessionStatus == .established {
            delegate?.removeLoginBox()
        }
    }
}
