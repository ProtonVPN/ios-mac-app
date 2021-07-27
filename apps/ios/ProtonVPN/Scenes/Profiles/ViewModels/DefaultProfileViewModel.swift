//
//  OneLineViewModel.swift
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

class DefaultProfileViewModel {
    
    private let serverOffering: ServerOffering
    private let vpnGateway: VpnGatewayProtocol?
    private let propertiesManager: PropertiesManagerProtocol
    private let loginService: LoginService
    private let connectionStatusService: ConnectionStatusService
    private let netShieldPropertyProvider: NetShieldPropertyProvider
    
    private var profile: Profile {
        switch serverOffering {
        case .random:
            return Profile(id: "st_r",
                           accessTier: 0,
                           profileIcon: .image("con-random"),
                           profileType: .system,
                           serverType: propertiesManager.serverTypeToggle,
                           serverOffering: serverOffering,
                           name: LocalizedString.random,
                           connectionProtocol: propertiesManager.connectionProtocol)
        default:
            return Profile(id: "st_f", accessTier: 0,
                           profileIcon: .image("con-fastest"),
                           profileType: .system,
                           serverType: propertiesManager.serverTypeToggle,
                           serverOffering: serverOffering,
                           name: LocalizedString.fastest,
                           connectionProtocol: propertiesManager.connectionProtocol)
        }
    }
    
    private var isConnected: Bool {
        if let vpnGateway = vpnGateway, let activeConnectionRequest = vpnGateway.lastConnectionRequest, vpnGateway.connection == .connected {
            return activeConnectionRequest == profile.connectionRequest(withDefaultNetshield: netShieldPropertyProvider.netShieldType)
        }
        return false
    }
    
    private var isConnecting: Bool {
        if let vpnGateway = vpnGateway, let activeConnectionRequest = vpnGateway.lastConnectionRequest, vpnGateway.connection == .connecting {
            return activeConnectionRequest == profile.connectionRequest(withDefaultNetshield: netShieldPropertyProvider.netShieldType)
        }
        return false
    }
    
    private var connectedUiState: Bool {
        return isConnected || isConnecting
    }
    
    var connectionChanged: (() -> Void)?
    
    let connectedConnectIcon = UIImage(named: "con-connected")
    
    var connectIcon: UIImage? {
        if connectedUiState {
            return connectedConnectIcon
        } else {
            return UIImage(named: "con-available")
        }
    }
    
    var title: String {
        switch serverOffering {
        case .fastest:
            return LocalizedString.fastestConnection
        case .random:
            return LocalizedString.randomConnection
        default:
            return ""
        }
    }
    
    var image: UIImage {
        switch serverOffering {
        case .fastest:
            return UIImage(named: "con-fastest")!
        case .random:
            return UIImage(named: "con-random")!
        default:
            return UIImage()
        }
    }
    
    init(serverOffering: ServerOffering, vpnGateway: VpnGatewayProtocol?, propertiesManager: PropertiesManagerProtocol, loginService: LoginService, connectionStatusService: ConnectionStatusService, netShieldPropertyProvider: NetShieldPropertyProvider) {
        self.serverOffering = serverOffering
        self.propertiesManager = propertiesManager
        self.vpnGateway = vpnGateway
        self.loginService = loginService
        self.connectionStatusService = connectionStatusService
        self.netShieldPropertyProvider = netShieldPropertyProvider
        
        startObserving()
    }
    
    func connectAction() {
        guard let vpnGateway = vpnGateway else {
            loginService.presentSignup()
            return
        }
        
        if isConnecting {
            vpnGateway.stopConnecting(userInitiated: true)
        } else if isConnected {
            vpnGateway.disconnect()
        } else {
            vpnGateway.connectTo(profile: profile)
            connectionStatusService.presentStatusViewController()
        }
    }
    
    // MARK: - Private functions
    private func startObserving() {
        NotificationCenter.default.addObserver(self, selector: #selector(stateChanged),
                                               name: VpnGateway.connectionChanged, object: nil)
    }
    
    @objc fileprivate func stateChanged() {
        if let connectionChanged = connectionChanged {
            connectionChanged()
        }
    }
}
