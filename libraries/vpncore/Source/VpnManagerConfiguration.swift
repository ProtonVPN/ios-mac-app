//
//  VpnManagerConfiguration.swift
//  ProtonVPN - Created on 30.07.19.
//
//
//  Copyright (c) 2019 Proton Technologies AG
//
//  See LICENSE for up to date license information.

import Foundation

public enum VpnManagerClientConfiguration: String {
    case iOSClient = "pi"
    case macClient = "pm"
}

public struct VpnManagerConfiguration {
    
    public static let configConcatChar: Character = "+"
    
    public let hostname: String
    public let serverId: String
    public let entryServerAddress: String
    public let exitServerAddress: String
    public let username: String
    public let password: String
    public let passwordReference: Data
    public let vpnProtocol: VpnProtocol
    
    public init(hostname: String, serverId: String, entryServerAddress: String, exitServerAddress: String, username: String, password: String, passwordReference: Data, vpnProtocol: VpnProtocol) {
        self.hostname = hostname
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
            
            return VpnManagerConfiguration(hostname: connectionConfig.serverIp.domain,
                                           serverId: connectionConfig.server.id,
                                           entryServerAddress: entryServer,
                                           exitServerAddress: exitServer,
                                           username: vpnCredentials.name + self.extraConfiguration,
                                           password: vpnCredentials.password,
                                           passwordReference: passwordRef,
                                           vpnProtocol: connectionConfig.vpnProtocol
            )
        } catch {
            // issues retrieving vpn keychain item
            alertService.push(alert: CannotAccessVpnCredentialsAlert())
            return nil
        }
    }
    
    // MARK: - Private
    
    private var extraConfiguration: String {
        
        #if os(iOS)
        let extraConfiguration: [VpnManagerClientConfiguration] = [.iOSClient]
        #else
        let extraConfiguration: [VpnManagerClientConfiguration] = [.macClient]
        #endif
        
        return extraConfiguration.reduce("") {
            $0 + "\(VpnManagerConfiguration.configConcatChar )" + $1.rawValue
        }
    }
}
