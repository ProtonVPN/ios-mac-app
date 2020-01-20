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
    
    private var cancelConnectionAttempt = false
    
    init(appStateManager: AppStateManager, vpnApiService: VpnApiService, alertService: CoreAlertService?, serverTierChecker: ServerTierChecker, vpnKeychain: VpnKeychainProtocol) {
        self.appStateManager = appStateManager
        self.vpnApiService = vpnApiService
        self.alertService = alertService
        self.serverTierChecker = serverTierChecker
        self.vpnKeychain = vpnKeychain
    }
    
    func prepareConnection(selectServerClosure: @escaping ([SessionModel]?) -> (ServerModel?)) {
        startConnectionProcess { [weak self] sessions in
            let server = selectServerClosure(sessions)
            if let configuration = self?.formConfiguration(fromServer: server, sessions: sessions) {
                guard let cancelConnectionAttempt = self?.cancelConnectionAttempt, !cancelConnectionAttempt else {
                    return // connection attempt cancelled
                }
                
                self?.appStateManager.connect(withConfiguration: configuration)
            }
        }
    }
    
    func cancelPreparingConnection() {
        cancelConnectionAttempt = true
        
        if case AppState.connecting = appStateManager.state {
            appStateManager.cancelConnectionAttempt()
        }
    }
    
    // MARK: - Private functions
    private func startConnectionProcess(completion: @escaping ([SessionModel]) -> Void) {
        self.getExistingSessions { sessions in
            completion(sessions)
        }
    }
    
    private func getExistingSessions(completion: @escaping ([SessionModel]) -> Void) {
        vpnApiService.sessions(success: { sessions in
            completion(sessions)
        }, failure: { [weak self] error in
            guard let `self` = self else { return }
            PMLog.D("Failed to retrieve active session info", level: .warn)
            if case AppState.preparingConnection = self.appStateManager.state {
                completion([])
            }
            return
        })
    }
    
    private func updateScores(completion: @escaping () -> Void) {
        vpnApiService.loads(success: { [weak self] (loads) in
            self?.serverStorage.update(continuousServerProperties: loads)
            completion()
        }, failure: { (_) in
            completion() // ignore errors
        })
    }
    
    private func formConfiguration(fromServer serverModel: ServerModel?, sessions: [SessionModel]?) -> VpnManagerConfiguration? {
        guard let server = serverModel else { return nil }
        do {
            let vpnCredentials = try vpnKeychain.fetch()
            let password = try vpnKeychain.fetchOpenVpnPassword()
            
            if let requiresUpgrade = serverTierChecker.serverRequiresUpgrade(server), requiresUpgrade {
                return nil
            }
            
            var serverIps: [ServerIp]
            if let sessions = sessions {
                serverIps = server.ips.filter { serverIp in
                    return !sessions.contains { session in
                        return session.vpnProtocol == .ikev2 && session.exitIp == serverIp.exitIp
                    }
                }
            } else {
                serverIps = server.ips
            }
            serverIps = serverIps.filter { !$0.underMaintenance }
            
            guard !serverIps.isEmpty else {
                serverTierChecker.notifyResolutionUnavailable(forSpecificCountry: false, type: server.serverType, reason: .existingConnection)
                return nil
            }
            
            let serverIp = serverIps[Int(arc4random_uniform(UInt32(serverIps.count)))]
            let entryServer = serverIp.entryIp
            let exitServer = serverIp.exitIp
            
            return VpnManagerConfiguration(serverId: server.id, entryServerAddress: entryServer, exitServerAddress: exitServer,
                                           username: vpnCredentials.name, password: password)
        } catch {
            // issues retrieving vpn keychain item
            alertService?.push(alert: CannotAccessVpnCredentialsAlert(confirmHandler: { [weak self] in
                self?.appStateManager.cancelConnectionAttempt()
            }))
            return nil
        }
    }
}
