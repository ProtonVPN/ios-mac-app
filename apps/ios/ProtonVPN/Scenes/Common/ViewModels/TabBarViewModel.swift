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
import LegacyCommon
import Domain
import ProtonCoreFeatureFlags

protocol TabBarViewModelModelDelegate: AnyObject {
    func removeLoginBox()
}

protocol TabBarViewModelDelegate: AnyObject {
    func connectedQuickConnect()
    func connectingQuickConnect()
    func disconnectedQuickConnect()
}

class TabBarViewModel {
    // MARK: Properties
    let navigationService: NavigationService
    let sessionManager: AppSessionManager
    let appStateManager: AppStateManager
    let vpnGateway: VpnGatewayProtocol
    let connectionStatusService: ConnectionStatusService
    weak var delegate: TabBarViewModelDelegate?
    
    var showLoginAnimated: Bool {
        return true
    }
    
    // MARK: Initializers
    init(navigationService: NavigationService, sessionManager: AppSessionManager, appStateManager: AppStateManager, vpnGateway: VpnGatewayProtocol) {
        self.navigationService = navigationService
        self.sessionManager = sessionManager
        self.appStateManager = appStateManager
        self.vpnGateway = vpnGateway
        self.connectionStatusService = navigationService
        
        startObserving()
    }
    
    // MARK: Functions
    
    func quickConnectTapped() {
        log.debug("Connect requested by clicking on Quick connect", category: .connectionConnect, event: .trigger)
        
        if vpnGateway.connection == .disconnected || vpnGateway.connection == .disconnecting {
            NotificationCenter.default.post(name: .userInitiatedVPNChange, object: UserInitiatedVPNChange.connect)
            vpnGateway.quickConnect(trigger: .quick)
            connectionStatusService.presentStatusViewController()
            
        } else if vpnGateway.connection == .connecting {
            log.debug("VPN is connecting. Will stop connecting.", category: .connectionDisconnect, event: .trigger)
            NotificationCenter.default.post(name: .userInitiatedVPNChange, object: UserInitiatedVPNChange.abort)
            vpnGateway.stopConnecting(userInitiated: true)
            
        } else {
            log.debug("VPN is connected already. Will be disconnected.", category: .connectionDisconnect, event: .trigger)
            NotificationCenter.default.post(name: .userInitiatedVPNChange, object: UserInitiatedVPNChange.disconnect(.quick))
            vpnGateway.disconnect()
        }
    }
    
    func settingShouldBeSelected() -> Bool {
        if sessionManager.loggedIn {
            return true
        } else {
            navigationService.presentWelcome(initialError: nil)
            return false
        }
    }
    
    @objc func stateChanged() {
        guard !FeatureFlagsRepository.shared.isEnabled(VPNFeatureFlagType.redesigniOS) else { return }
        DispatchQueue.main.async { [weak self] in
            switch self?.appStateManager.displayState {
            case .connected:
                self?.delegate?.connectedQuickConnect()
            case .loadingConnectionInfo, .connecting:
                self?.delegate?.connectingQuickConnect()
            default:
                self?.delegate?.disconnectedQuickConnect()
            }
        }
    }

    func settingsTabTapped() {
        sessionManager.refreshUserInfo()
    }

    // MARK: - Private
    private func startObserving() {
        NotificationCenter.default.addObserver(self, selector: #selector(stateChanged),
                                               name: .AppStateManager.displayStateChange, object: nil)
    }
}
