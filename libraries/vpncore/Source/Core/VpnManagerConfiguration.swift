//
//  VpnManagerConfiguration.swift
//  ProtonVPN - Created on 30.07.19.
//
//
//  Copyright (c) 2019 Proton Technologies AG
//
//  See LICENSE for up to date license information.

import Foundation

public enum VpnManagerClientConfiguration {
    case iOSClient
    case macClient
    case netShieldLevel1
    case netShieldLevel2
    case vpnAccelerator
    case label(String)

    var usernameSuffix: String {
        switch self {
        case .iOSClient:
            return "pi"
        case .macClient:
            return "pm"
        case .vpnAccelerator:
            return "nst"
        case .netShieldLevel1:
            return "f1"
        case .netShieldLevel2:
            return "f2"
        case let .label(label):
            return "b:\(label)"
        }
    }
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
    public let preferredPorts: [Int]?
    public let netShield: NetShieldType
    public let vpnAccelerator: Bool
    public let bouncing: String?
    
    public init(hostname: String, serverId: String, entryServerAddress: String, exitServerAddress: String, username: String, password: String, passwordReference: Data, authData: VpnAuthenticationData?, vpnProtocol: VpnProtocol, netShield: NetShieldType, vpnAccelerator: Bool, bouncing: String?, preferredPorts: [Int]?) {
        self.hostname = hostname
        self.serverId = serverId
        self.entryServerAddress = entryServerAddress
        self.exitServerAddress = exitServerAddress
        self.username = username
        self.password = password
        self.passwordReference = passwordReference
        self.authData = authData
        self.vpnProtocol = vpnProtocol
        self.netShield = netShield
        self.vpnAccelerator = vpnAccelerator
        self.preferredPorts = preferredPorts
        self.bouncing = bouncing
    }
}

public protocol VpnManagerConfigurationPreparerFactory {
    func makeVpnManagerConfigurationPreparer() -> VpnManagerConfigurationPreparer
}

public class VpnManagerConfigurationPreparer {
    
    private let vpnKeychain: VpnKeychainProtocol
    private let alertService: CoreAlertService
    private let propertiesManager: PropertiesManagerProtocol
    
    public init(vpnKeychain: VpnKeychainProtocol, alertService: CoreAlertService, propertiesManager: PropertiesManagerProtocol) {
        self.vpnKeychain = vpnKeychain
        self.alertService = alertService
        self.propertiesManager = propertiesManager
    }
    
    public func prepareConfiguration(from connectionConfig: ConnectionConfiguration, authData: VpnAuthenticationData?) -> VpnManagerConfiguration? {
        do {
            let vpnCredentials = try vpnKeychain.fetch()
            let passwordRef = try vpnKeychain.fetchOpenVpnPassword()
            
            let entryServer = connectionConfig.serverIp.entryIp
            let exitServer = connectionConfig.serverIp.exitIp
            
            return VpnManagerConfiguration(hostname: connectionConfig.serverIp.domain,
                                           serverId: connectionConfig.server.id,
                                           entryServerAddress: entryServer,
                                           exitServerAddress: exitServer,
                                           username: vpnCredentials.name + self.extraConfiguration(with: connectionConfig),
                                           password: vpnCredentials.password,
                                           passwordReference: passwordRef,
                                           authData: authData,
                                           vpnProtocol: connectionConfig.vpnProtocol,
                                           netShield: connectionConfig.netShieldType,
                                           vpnAccelerator: !propertiesManager.featureFlags.isVpnAccelerator || propertiesManager.vpnAcceleratorEnabled,
                                           bouncing: connectionConfig.serverIp.label,
                                           preferredPorts: connectionConfig.preferredPorts
            )
        } catch {
            // issues retrieving vpn keychain item
            alertService.push(alert: CannotAccessVpnCredentialsAlert())
            return nil
        }
    }
    
    // MARK: - Private
    
    private func extraConfiguration(with connectionConfig: ConnectionConfiguration) -> String {
        
        #if os(iOS)
        var extraConfiguration: [VpnManagerClientConfiguration] = [.iOSClient]
        #else
        var extraConfiguration: [VpnManagerClientConfiguration] = [.macClient]
        #endif
        
        if propertiesManager.featureFlags.isNetShield {
            extraConfiguration += connectionConfig.netShieldType.vpnManagerClientConfigurationFlags
        }

        if propertiesManager.featureFlags.isVpnAccelerator && !propertiesManager.vpnAcceleratorEnabled {
            // VPN accelerator works with opposite logic, we send this suffix in case of NOT activated and feature enabled
            extraConfiguration += [.vpnAccelerator]
        }
        
        if let label = connectionConfig.serverIp.label, !label.isEmpty {
            extraConfiguration += [.label(label)]
        }
        
        return extraConfiguration.reduce("") {
            $0 + "\(VpnManagerConfiguration.configConcatChar )" + $1.usernameSuffix
        }
    }
}
