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
import LegacyCommon
import ProtonCoreUIFoundations

class DefaultProfileViewModel {
    
    private let serverOffering: ServerOffering
    private let vpnGateway: VpnGatewayProtocol
    private let propertiesManager: PropertiesManagerProtocol
    private let connectionStatusService: ConnectionStatusService
    private let netShieldPropertyProvider: NetShieldPropertyProvider
    private let natTypePropertyProvider: NATTypePropertyProvider
    private let safeModePropertyProvider: SafeModePropertyProvider
    
    private var profile: Profile {
        switch serverOffering {
        case .random:
            return Profile(id: "st_r",
                           accessTier: 0,
                           profileIcon: .image(IconProvider.arrowsSwapRight),
                           profileType: .system,
                           serverType: propertiesManager.serverTypeToggle,
                           serverOffering: serverOffering,
                           name: LocalizedString.random,
                           connectionProtocol: propertiesManager.connectionProtocol)
        default:
            return Profile(id: "st_f",
                           accessTier: 0,
                           profileIcon: .image(IconProvider.bolt),
                           profileType: .system,
                           serverType: propertiesManager.serverTypeToggle,
                           serverOffering: serverOffering,
                           name: LocalizedString.fastest,
                           connectionProtocol: propertiesManager.connectionProtocol)
        }
    }
    
    var isConnected: Bool {
        if let activeConnectionRequest = vpnGateway.lastConnectionRequest, vpnGateway.connection == .connected {
            return activeConnectionRequest == profile.connectionRequest(withDefaultNetshield: netShieldPropertyProvider.netShieldType, withDefaultNATType: natTypePropertyProvider.natType, withDefaultSafeMode: safeModePropertyProvider.safeMode, trigger: .profile)
        }
        return false
    }
    
    private var isConnecting: Bool {
        if let activeConnectionRequest = vpnGateway.lastConnectionRequest, vpnGateway.connection == .connecting {
            return activeConnectionRequest == profile.connectionRequest(withDefaultNetshield: netShieldPropertyProvider.netShieldType, withDefaultNATType: natTypePropertyProvider.natType, withDefaultSafeMode: safeModePropertyProvider.safeMode, trigger: .profile)
        }
        return false
    }
    
    private var connectedUiState: Bool {
        return isConnected || isConnecting
    }
    
    var connectionChanged: (() -> Void)?
    
    var connectIcon: UIImage? = IconProvider.powerOff
    
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
            return IconProvider.bolt
        case .random:
            return IconProvider.arrowsSwapRight
        default:
            return UIImage()
        }
    }
    
    init(serverOffering: ServerOffering, vpnGateway: VpnGatewayProtocol, propertiesManager: PropertiesManagerProtocol, connectionStatusService: ConnectionStatusService, netShieldPropertyProvider: NetShieldPropertyProvider, natTypePropertyProvider: NATTypePropertyProvider, safeModePropertyProvider: SafeModePropertyProvider) {
        self.serverOffering = serverOffering
        self.propertiesManager = propertiesManager
        self.vpnGateway = vpnGateway
        self.connectionStatusService = connectionStatusService
        self.netShieldPropertyProvider = netShieldPropertyProvider
        self.natTypePropertyProvider = natTypePropertyProvider
        self.safeModePropertyProvider = safeModePropertyProvider
        
        startObserving()
    }
    
    func connectAction() {
        log.debug("Connect requested by selecting default profile.", category: .connectionConnect, event: .trigger)
        
        if isConnecting {
            NotificationCenter.default.post(name: .userInitiatedVPNChange, object: UserInitiatedVPNChange.abort)
            log.debug("VPN is connecting. Will stop connecting.", category: .connectionDisconnect, event: .trigger)
            vpnGateway.stopConnecting(userInitiated: true)
        } else if isConnected {
            NotificationCenter.default.post(name: .userInitiatedVPNChange, object: UserInitiatedVPNChange.disconnect(.profile))
            log.debug("VPN is connected already. Will be disconnected.", category: .connectionDisconnect, event: .trigger)
            vpnGateway.disconnect()
        } else {
            NotificationCenter.default.post(name: .userInitiatedVPNChange, object: UserInitiatedVPNChange.connect)
            log.debug("Will connect to \(profile.logDescription)", category: .connectionConnect, event: .trigger)
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
