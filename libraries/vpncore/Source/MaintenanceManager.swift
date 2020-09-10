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
    func observeCurrentServerState(every timeInterval: TimeInterval, repeats: Bool, completion: BoolCallback?, failure: ErrorCallback?)
}

public class MaintenanceManager: MaintenanceManagerProtocol {
    
    public typealias Factory = VpnApiServiceFactory & AppStateManagerFactory & VpnGatewayFactory & CoreAlertServiceFactory & ServerStorageFactory
    
    private let factory: Factory
    
    private lazy var vpnApiService: VpnApiService = self.factory.makeVpnApiService()
    private lazy var appStateManager: AppStateManager = self.factory.makeAppStateManager()
    private lazy var vpnGateWay: VpnGatewayProtocol = self.factory.makeVpnGateway()
    private lazy var alertService: CoreAlertService = self.factory.makeCoreAlertService()
    private lazy var serverStorage: ServerStorage = self.factory.makeServerStorage()
    
    public init( factory: Factory) {
        self.factory = factory
    }
    
    // MARK: - MaintenanceManagerProtocol
    
    public func observeCurrentServerState(every timeInterval: TimeInterval, repeats: Bool, completion: BoolCallback?, failure: ErrorCallback?) {
        if !repeats || timeInterval <= 0 {
            self.checkServer(completion, failure: failure)
            return
        }
        
        Timer.scheduledTimer(withTimeInterval: timeInterval, repeats: true) { timer in
            self.checkServer(completion, failure: failure)
        }
    }
    
    private func checkServer(_ completion: BoolCallback?, failure: ErrorCallback?) {
        guard let activeConnection = appStateManager.activeConnection() else {
            PMLog.D("No active connection", level: .info)
            completion?(false)
            return
        }
        
        switch appStateManager.state {
        case .connected, .connecting:
            break
        default:
            PMLog.D("VPN Not connected", level: .info)
            completion?(false)
            return
        }
        
        let serverID = activeConnection.serverIp.id
        
        let failureCallback: ErrorCallback = { error in
            PMLog.D("Server check request failed with error: \(error)", level: .error)
            self.vpnGateWay.disconnect { }
            failure?(error)
        }
        
        vpnApiService.serverState(serverId: serverID, success: { vpnServerState in
            guard vpnServerState.status != 1 else {
                completion?(false)
                return
            }
            
            self.vpnApiService.serverInfo(for: nil, success: { servers in
                self.serverStorage.store(servers)
                self.alertService.push(alert: VpnServerOnMaintenanceAlert())
                self.vpnGateWay.quickConnect()
                completion?(true)
            }, failure: failureCallback)
        }, failure: failureCallback)
    }
}
