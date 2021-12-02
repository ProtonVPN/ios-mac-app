//
//  VpnProtocolChangeManager.swift
//  ProtonVPN - Created on 2021-04-09.
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

protocol VpnProtocolChangeManagerFactory {
    func makeVpnProtocolChangeManager() -> VpnProtocolChangeManager
}

extension DependencyContainer: VpnProtocolChangeManagerFactory {
    func makeVpnProtocolChangeManager() -> VpnProtocolChangeManager {
        return VpnProtocolChangeManagerImplementation(factory: self)
    }
}

/// Class to request VPN protocol change.
/// Takes care of checking if user is currently connected, if sysex is installed, etc.
protocol VpnProtocolChangeManager {
    func change(toProcol: VpnProtocol)
}

final class VpnProtocolChangeManagerImplementation: VpnProtocolChangeManager {
    
    typealias Factory = PropertiesManagerFactory
        & CoreAlertServiceFactory
        & SystemExtensionManagerFactory
        & VpnGatewayFactory
        & SystemExtensionsStateCheckFactory
    private let factory: Factory
    
    private lazy var propertiesManager: PropertiesManagerProtocol = factory.makePropertiesManager()
    private lazy var alertService: CoreAlertService = factory.makeCoreAlertService()
    private lazy var systemExtensionManager: SystemExtensionManager = factory.makeSystemExtensionManager()
    private lazy var vpnGateway: VpnGatewayProtocol = factory.makeVpnGateway()
    private lazy var systemExtensionsStateCheck: SystemExtensionsStateCheck = factory.makeSystemExtensionsStateCheck()
    
    init(factory: Factory) {
        self.factory = factory
    }
    
    func change(toProcol vpnProtocol: VpnProtocol) {
        guard vpnGateway.connection == .connected || vpnGateway.connection == .connecting else {
            set(vpnProtocol: vpnProtocol, reconnect: false)
            return
        }
        
        alertService.push(alert: ReconnectOnSettingsChangeAlert { [weak self] in
            self?.set(vpnProtocol: vpnProtocol, reconnect: true)
        })
    }
    
    private func set(vpnProtocol: VpnProtocol, reconnect: Bool) {
        let reconnectIfNeeded = { [weak self] in
            if reconnect {
                log.info("New protocol set to \(vpnProtocol). VPN will reconnect.", category: .connectionConnect, event: .trigger)
                self?.vpnGateway.reconnect(with: ConnectionProtocol.vpnProtocol(vpnProtocol))
            }
        }

        switch vpnProtocol {
        case .ike:
            propertiesManager.vpnProtocol = vpnProtocol
            reconnectIfNeeded()
        
        case .openVpn, .wireGuard:
            systemExtensionsStateCheck.startCheckAndInstallIfNeeded { result in
                switch result {
                case .success:
                    self.propertiesManager.vpnProtocol = vpnProtocol
                    reconnectIfNeeded()
                    
                case .failure:
                    log.error("Protocol (\(vpnProtocol)) was not set because sysex check/installation failed", category: .connectionConnect)
                }
            }
            
        }
        
    }
        
}
