//
//  VpnManagerConfiguration.swift
//  ProtonVPN - Created on 30.07.19.
//
//
//  Copyright (c) 2019 Proton Technologies AG
//
//  See LICENSE for up to date license information.

import Foundation

public struct VpnManagerConfiguration {
    
    public let serverId: String
    public let entryServerAddress: String
    public let exitServerAddress: String
    public let username: String
    public let password: String
    public let passwordReference: Data
    public let vpnProtocol: VpnProtocol
    
    public init(serverId: String, entryServerAddress: String, exitServerAddress: String, username: String, password: String, passwordReference: Data, vpnProtocol: VpnProtocol) {
        self.serverId = serverId
        self.entryServerAddress = entryServerAddress
        self.exitServerAddress = exitServerAddress
        self.username = username
        self.password = password
        self.passwordReference = passwordReference
        self.vpnProtocol = vpnProtocol
    }
}

public protocol VpnManagerConfigurationPreparerFactory {
    func makeVpnManagerConfigurationPreparer() -> VpnManagerConfigurationPreparer
}

public class VpnManagerConfigurationPreparer {
    
    private let vpnKeychain: VpnKeychainProtocol
    private let alertService: CoreAlertService
    
    public init(vpnKeychain: VpnKeychainProtocol, alertService: CoreAlertService) {
        self.vpnKeychain = vpnKeychain
        self.alertService = alertService
    }
    
    public func prepareConfiguration(from connectionConfig: ConnectionConfiguration) -> VpnManagerConfiguration? {
        do {
            let vpnCredentials = try vpnKeychain.fetch()
            let passwordRef = try vpnKeychain.fetchOpenVpnPassword()
            
            let entryServer = connectionConfig.serverIp.entryIp
            let exitServer = connectionConfig.serverIp.exitIp
            
            return VpnManagerConfiguration(serverId: connectionConfig.server.id, entryServerAddress: entryServer, exitServerAddress: exitServer,
                                           username: vpnCredentials.name, password: vpnCredentials.password, passwordReference: passwordRef, vpnProtocol: connectionConfig.vpnProtocol)
        } catch {
            // issues retrieving vpn keychain item
            alertService.push(alert: CannotAccessVpnCredentialsAlert())
            return nil
        }
    }
}
