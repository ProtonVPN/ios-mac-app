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

protocol TabBarViewModelModelDelegate: AnyObject {
    func removeLoginBox()
}

protocol TabBarViewModelDelegate: AnyObject {
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
            switch self?.appStateManager.displayState {
            case .connected:
                self?.delegate?.connectedQuickConnect()
            case .preparingConnection, .connecting:
                self?.delegate?.connectingQuickConnect()
            default:
                self?.delegate?.disconnectedQuickConnect()
            }
        }
    }
    
    // MARK: - Private
    private func startObserving() {
        NotificationCenter.default.addObserver(self, selector: #selector(stateChanged),
                                               name: appStateManager.displayStateChange, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(sessionChanged),
                                               name: sessionManager.sessionChanged, object: nil)
    }
    
    @objc private func sessionChanged(_ notification: Notification) {
        if sessionManager.sessionStatus == .established {
            delegate?.removeLoginBox()
        }
    }
}
