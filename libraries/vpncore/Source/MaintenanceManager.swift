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
    func observeCurrentServerState(every timeInterval: TimeInterval, repeats: Bool, callback: BoolCallback?)
}

public class MaintenanceManager: MaintenanceManagerProtocol {
    
    private let vpnApiService: VpnApiService
    private let appStateManager: AppStateManager
    private let vpnGateWay: VpnGatewayProtocol
    private let alertService: CoreAlertService
    
    public init(vpnApiService: VpnApiService, appStateManager: AppStateManager, vpnGateWay: VpnGatewayProtocol, alertService: CoreAlertService) {
        self.vpnApiService = vpnApiService
        self.appStateManager = appStateManager
        self.vpnGateWay = vpnGateWay
        self.alertService = alertService
    }
    
    // MARK: - MaintenanceManagerProtocol
    
    public func observeCurrentServerState(every timeInterval: TimeInterval, repeats: Bool, callback: BoolCallback?) {
        if !repeats || timeInterval <= 0 {
            self.checkServer(callback)
            return
        }
        
        Timer.scheduledTimer(withTimeInterval: timeInterval, repeats: true) { timer in
            self.checkServer(callback)
        }
    }
    
    private func checkServer(_ callback: BoolCallback?) {
        guard let activeConnection = appStateManager.activeConnection() else {
            callback?(false)
            return
        }
        
        switch vpnGateWay.connection {
        case .connected, .connecting:
            break
        default:
            callback?(false)
            return
        }
        
        let serverID = activeConnection.serverIp.id
        
        let failureCallback: ErrorCallback = { error in
            PMLog.D("Server check request failed with error: \(error)", level: .error)
            self.vpnGateWay.quickConnect()
            callback?(true)
        }
        
        vpnApiService.serverState(serverId: serverID, success: { vpnServerState in
            guard vpnServerState.status != 1 else {
                callback?(false)
                return
            }
            
            self.vpnApiService.vpnProperties(lastKnownIp: nil, success: { _ in
                PMLog.D("Reconnecting to a new Server, current one on maintenance ID = \(serverID)", level: .info)
                callback?(true)
                self.alertService.push(alert: VpnServerOnMaintenanceAlert())
                self.vpnGateWay.quickConnect()
            }, failure: failureCallback)
            
        }, failure: failureCallback)
    }
}
