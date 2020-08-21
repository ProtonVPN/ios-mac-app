//
//  MaintenanceManager.swift
//  vpncore - Created on 20/08/2020.
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
//

import Foundation

public protocol MaintenanceManagerFactory {
    func makeMaintenanceManager() -> MaintenanceManagerProtocol
}

public protocol MaintenanceManagerProtocol {
    func observeCurrentServerState( serverObservedCallback: @escaping BoolCallback )
}

public class MaintenanceManager: MaintenanceManagerProtocol {
   
    private let vpnApiService: VpnApiService
    private let appStateManager: AppStateManager
    private let vpnGateWay: VpnGatewayProtocol
    private let alertService: CoreAlertService
        
    public init( _ vpnApiService: VpnApiService, _ appStateManager: AppStateManager, _ vpnGateWay: VpnGatewayProtocol, alertService:CoreAlertService ){
        self.vpnApiService = vpnApiService
        self.appStateManager = appStateManager
        self.vpnGateWay = vpnGateWay
        self.alertService = alertService
    }
    
    // MARK: - MaintenanceManagerProtocol
        
    public func observeCurrentServerState (serverObservedCallback: @escaping BoolCallback) {
        
        guard let activeConnection = appStateManager.activeConnection() else {
            serverObservedCallback(false)
            return
        }
        
        switch vpnGateWay.connection {
        case .connected, .connecting:
            break
        default:
            serverObservedCallback(false)
            return
        }

        let serverID = activeConnection.serverIp.id
        
        vpnApiService.serverState(serverId: serverID, success: { vpnServerState in
            if vpnServerState.status != 1 {
                serverObservedCallback(true)
                self.alertService.push(alert: VpnServerOnMaintenanceAlert())
                self.vpnGateWay.quickConnect()
            } else {
                serverObservedCallback(false)
            }
        }){ error in
            //Something
            serverObservedCallback(false)
        }
    }
    
    public var getBestScoredServer: ServerModel? {
        guard let tier = try? vpnGateWay.userTier() else {
            return nil
        }
        return nil
    }
}
