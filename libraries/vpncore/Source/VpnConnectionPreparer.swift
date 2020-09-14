//
//  VpnConnectionPreparer.swift
//  vpncore - Created on 26.06.19.
//
//  Copyright (c) 2019 Proton Technologies AG
//
//  This file is part of vpncore.
//
//  vpncore is free software: you can redistribute it and/or modify
//  it under the terms of the GNU General Public License as published by
//  the Free Software Foundation, either version 3 of the License, or
//  (at your option) any later version.
//
//  vpncore is distributed in the hope that it will be useful,
//  but WITHOUT ANY WARRANTY; without even the implied warranty of
//  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
//  GNU General Public License for more details.
//
//  You should have received a copy of the GNU General Public License
//  along with vpncore.  If not, see <https://www.gnu.org/licenses/>.

import Foundation

class VpnConnectionPreparer {
    
    private let appStateManager: AppStateManager
    private let vpnApiService: VpnApiService
    private let serverStorage: ServerStorage = ServerStorageConcrete()
    private let serverTierChecker: ServerTierChecker
    private let vpnKeychain: VpnKeychainProtocol
    
    public weak var alertService: CoreAlertService?
    
    init(appStateManager: AppStateManager, vpnApiService: VpnApiService, alertService: CoreAlertService?, serverTierChecker: ServerTierChecker, vpnKeychain: VpnKeychainProtocol) {
        self.appStateManager = appStateManager
        self.vpnApiService = vpnApiService
        self.alertService = alertService
        self.serverTierChecker = serverTierChecker
        self.vpnKeychain = vpnKeychain
    }
    
    func connect(withProtocol vpnProtocol: VpnProtocol, server: ServerModel, netShieldType: NetShieldType) {
        if let configuration = formConfiguration(withProtocol: vpnProtocol, fromServer: server, netShieldType: netShieldType) {
            appStateManager.connect(withConfiguration: configuration)
        }
    }
    
    // MARK: - Private functions
    private func formConfiguration(withProtocol vpnProtocol: VpnProtocol, fromServer serverModel: ServerModel?, netShieldType: NetShieldType) -> ConnectionConfiguration? {
        guard let server = serverModel else { return nil }
        
        if let requiresUpgrade = serverTierChecker.serverRequiresUpgrade(server), requiresUpgrade {
            return nil
        }
        
        let availableServerIps = server.ips.filter { !$0.underMaintenance }
        
        guard !availableServerIps.isEmpty else {
            serverTierChecker.notifyResolutionUnavailable(forSpecificCountry: false, type: server.serverType, reason: .existingConnection)
            return nil
        }
        
        let serverIp = availableServerIps[Int(arc4random_uniform(UInt32(availableServerIps.count)))]
        
        return ConnectionConfiguration(server: server, serverIp: serverIp, vpnProtocol: vpnProtocol, netShieldType: netShieldType)
    }
}
