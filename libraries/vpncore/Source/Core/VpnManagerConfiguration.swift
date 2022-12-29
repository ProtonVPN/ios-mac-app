//
//  VpnManagerConfiguration.swift
//  ProtonVPN - Created on 30.07.19.
//
//
//  Copyright (c) 2019 Proton Technologies AG
//
//  See LICENSE for up to date license information.

import Foundation
import VPNShared

public enum VpnManagerClientConfiguration {
    case iOSClient
    case macClient
    case netShieldLevel1
    case netShieldLevel2
    case vpnAccelerator
    case label(String)
    case moderateNAT
    case safeMode(Bool)

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
        case .moderateNAT:
            return "nr"
        case let .safeMode(enabled):
            return enabled ? "sm" : "nsm"
        }
    }
}

public struct VpnManagerConfiguration {
    
    public static let configConcatChar: Character = "+"
    
    public let hostname: String
    public let serverId: String
    public let ipId: String
    public let entryServerAddress: String
    public let exitServerAddress: String
    public let username: String
    public let password: String
    public let passwordReference: Data
    public let clientPrivateKey: String?
    public let vpnProtocol: VpnProtocol
    public let ports: [Int]
    public let netShield: NetShieldType
    public let vpnAccelerator: Bool
    public let bouncing: String?
    public let serverPublicKey: String?
    public let natType: NATType
    public let safeMode: Bool?
    
    public init(hostname: String, serverId: String, ipId: String, entryServerAddress: String, exitServerAddress: String, username: String, password: String, passwordReference: Data, clientPrivateKey: String?, vpnProtocol: VpnProtocol, netShield: NetShieldType, vpnAccelerator: Bool, bouncing: String?, natType: NATType, safeMode: Bool?, ports: [Int], serverPublicKey: String?) {
        self.hostname = hostname
        self.serverId = serverId
        self.ipId = ipId
        self.entryServerAddress = entryServerAddress
        self.exitServerAddress = exitServerAddress
        self.username = username
        self.password = password
        self.passwordReference = passwordReference
        self.clientPrivateKey = clientPrivateKey
        self.vpnProtocol = vpnProtocol
        self.netShield = netShield
        self.vpnAccelerator = vpnAccelerator
        self.ports = ports
        self.bouncing = bouncing
        self.natType = natType
        self.safeMode = safeMode
        self.serverPublicKey = serverPublicKey
    }
}

public protocol VpnManagerConfigurationPreparerFactory {
    func makeVpnManagerConfigurationPreparer() -> VpnManagerConfigurationPreparer
}

public class VpnManagerConfigurationPreparer {
    private let vpnKeychain: VpnKeychainProtocol
    private let alertService: CoreAlertService
    private let propertiesManager: PropertiesManagerProtocol

    public typealias Factory = VpnKeychainFactory &
        CoreAlertServiceFactory &
        PropertiesManagerFactory

    public convenience init(_ factory: Factory) {
        self.init(vpnKeychain: factory.makeVpnKeychain(),
                  alertService: factory.makeCoreAlertService(),
                  propertiesManager: factory.makePropertiesManager())
    }
    
    public init(vpnKeychain: VpnKeychainProtocol, alertService: CoreAlertService, propertiesManager: PropertiesManagerProtocol) {
        self.vpnKeychain = vpnKeychain
        self.alertService = alertService
        self.propertiesManager = propertiesManager
    }
    
    public func prepareConfiguration(from connectionConfig: ConnectionConfiguration, clientPrivateKey: PrivateKey?) -> VpnManagerConfiguration? {
        guard let entryServer = connectionConfig.serverIp.entryIp(using: connectionConfig.vpnProtocol) else {
            log.error("No entry IP is available for \(connectionConfig.vpnProtocol.localizedString).")
            return nil
        }

        do {
            let vpnCredentials = try vpnKeychain.fetch()
            let passwordRef = try vpnKeychain.fetchOpenVpnPassword()
            
            let exitServer = connectionConfig.serverIp.exitIp
            
            return VpnManagerConfiguration(hostname: connectionConfig.serverIp.domain,
                                           serverId: connectionConfig.server.id,
                                           ipId: connectionConfig.serverIp.id,
                                           entryServerAddress: entryServer,
                                           exitServerAddress: exitServer,
                                           username: vpnCredentials.name + self.extraConfiguration(with: connectionConfig),
                                           password: vpnCredentials.password,
                                           passwordReference: passwordRef,
                                           clientPrivateKey: clientPrivateKey?.base64X25519Representation,
                                           vpnProtocol: connectionConfig.vpnProtocol,
                                           netShield: connectionConfig.netShieldType,
                                           vpnAccelerator: !propertiesManager.featureFlags.vpnAccelerator || propertiesManager.vpnAcceleratorEnabled,
                                           bouncing: connectionConfig.serverIp.label,
                                           natType: connectionConfig.natType,
                                           safeMode: connectionConfig.safeMode,
                                           ports: connectionConfig.ports,
                                           serverPublicKey: connectionConfig.serverIp.x25519PublicKey
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
        
        if propertiesManager.featureFlags.netShield {
            extraConfiguration += connectionConfig.netShieldType.vpnManagerClientConfigurationFlags
        }

        if propertiesManager.featureFlags.vpnAccelerator && !propertiesManager.vpnAcceleratorEnabled {
            // VPN accelerator works with opposite logic, we send this suffix in case of NOT activated and feature enabled
            extraConfiguration += [.vpnAccelerator]
        }
        
        if let label = connectionConfig.serverIp.label, !label.isEmpty {
            extraConfiguration += [.label(label)]
        }

        if propertiesManager.featureFlags.moderateNAT, connectionConfig.natType == .moderateNAT {
            extraConfiguration += [.moderateNAT]
        }

        if propertiesManager.featureFlags.safeMode, let safeMode = connectionConfig.safeMode {
            extraConfiguration += [.safeMode(safeMode)]
        }
        
        return extraConfiguration.reduce("") {
            $0 + "\(VpnManagerConfiguration.configConcatChar )" + $1.usernameSuffix
        }
    }
}
