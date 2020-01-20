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
    private let loginService: LoginService
    
    var connectionChanged: (() -> Void)?
    
    var isConnected: Bool {
        if let vpnGateway = vpnGateway, let activeConnectionRequest = vpnGateway.activeConnectionRequest, (vpnGateway.connection == .connected || vpnGateway.connection == .connecting) {
            switch activeConnectionRequest.connectionType {
            case .fastest:
                return serverOffering == .fastest(nil)
            case .random:
                return serverOffering == .random(nil)
            default:
                return false
            }
        }
        return false
    }
    
    let connectedConnectIcon = UIImage(named: "con-connected")
    
    var connectIcon: UIImage? {
        if isConnected {
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
    
    init(serverOffering: ServerOffering, vpnGateway: VpnGatewayProtocol?, loginService: LoginService) {
        self.serverOffering = serverOffering
        self.vpnGateway = vpnGateway
        self.loginService = loginService
        
        startObserving()
    }
    
    func connectAction(delegate: ConnectingCellDelegate) {
        guard let vpnGateway = vpnGateway else {
            loginService.presentSignup()
            return
        }
        
        if vpnGateway.connection == .connecting, delegate === vpnGateway.connectingCellDelegate {
            vpnGateway.stopConnecting(userInitiated: true)
        } else if isConnected {
            vpnGateway.disconnect()
        } else {
            if let delegate = vpnGateway.connectingCellDelegate {
                vpnGateway.stopConnecting(userInitiated: true)
                delegate.disableConnecting()
            }
            
            vpnGateway.connectingCellDelegate = delegate
            switch serverOffering {
            case .fastest:
                let profile = Profile(id: "st_f", accessTier: 0, profileIcon: .image("con-fastest"), profileType: .system,
                                      serverType: vpnGateway.activeServerType, serverOffering: serverOffering, name: LocalizedString.fastest)
                vpnGateway.connectTo(profile: profile)
            case .random:
                let profile = Profile(id: "st_r", accessTier: 0, profileIcon: .image("con-random"), profileType: .system,
                                      serverType: vpnGateway.activeServerType, serverOffering: serverOffering, name: LocalizedString.random)
                vpnGateway.connectTo(profile: profile)
            default:
                break
            }
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
