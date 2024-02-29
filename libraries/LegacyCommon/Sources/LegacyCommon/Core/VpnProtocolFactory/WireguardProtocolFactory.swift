//
//  WireguardProtocolFactory.swift
//  LegacyCommon
//
//  Created by Jaroslav on 2021-05-17.
//  Copyright © 2021 Proton Technologies AG. All rights reserved.
//

import Foundation
import NetworkExtension
import ProtonCoreFeatureFlags

import ExtensionIPC
import VPNShared
import Domain

public protocol WireguardProtocolFactoryCreator {
    func makeWireguardProtocolFactory() -> WireguardProtocolFactory
}

open class WireguardProtocolFactory {
    private let bundleId: String
    private let appGroup: String
    private let propertiesManager: PropertiesManagerProtocol
    private let vpnManagerFactory: NETunnelProviderManagerWrapperFactory

    private var vpnManager: NETunnelProviderManagerWrapper?

    public typealias Factory = PropertiesManagerFactory &
        NETunnelProviderManagerWrapperFactory

    public convenience init(_ factory: Factory, config: Container.Config) {
        self.init(bundleId: config.wireguardVpnExtensionBundleIdentifier,
                  appGroup: config.appGroup,
                  propertiesManager: factory.makePropertiesManager(),
                  vpnManagerFactory: factory)
    }
    
    public init(bundleId: String,
                appGroup: String,
                propertiesManager: PropertiesManagerProtocol,
                vpnManagerFactory: NETunnelProviderManagerWrapperFactory) {
        self.bundleId = bundleId
        self.appGroup = appGroup
        self.propertiesManager = propertiesManager
        self.vpnManagerFactory = vpnManagerFactory
    }
        
    open func logs(completion: @escaping (String?) -> Void) {
        guard let fileUrl = logFile() else {
            completion(nil)
            return
        }
        do {
            let log = try String(contentsOf: fileUrl)
            completion(log)
        } catch {
            log.error("Error reading WireGuard log file", category: .app, metadata: ["error": "\(error)"])
            completion(nil)
        }
    }
}

extension WireguardProtocolFactory: VpnProtocolFactory {
    public func create(_ configuration: VpnManagerConfiguration) throws -> NEVPNProtocol {
        let protocolConfiguration = NETunnelProviderProtocol()
        protocolConfiguration.providerBundleIdentifier = bundleId
        protocolConfiguration.serverAddress = configuration.entryServerAddress
        protocolConfiguration.connectedLogicalId = configuration.serverId
        protocolConfiguration.connectedServerIpId = configuration.ipId
        protocolConfiguration.featureFlagOverrides = propertiesManager.featureFlags.localOverrides

        // Future: remove this flag and the plumbing that goes all the way to CertificateRefreshRequest.withPublicKey
        // in the NEHelper module and in `parameters` in the CertificateRequest struct in LegacyCommon. (VPNAPPL-2134)
        if FeatureFlagsRepository.shared.isEnabled(VPNFeatureFlagType.certificateRefreshForceRenew, reloadValue: true) {
            protocolConfiguration.unleashFeatureFlagShouldForceConflictRefresh = true
        }

        return protocolConfiguration
    }
    
    public func vpnProviderManager(for requirement: VpnProviderManagerRequirement, completion: @escaping (NEVPNManagerWrapper?, Error?) -> Void) {
        if requirement == .status, let vpnManager = vpnManager {
            completion(vpnManager, nil)
        } else {
            vpnManagerFactory.tunnelProviderManagerWrapper(forProviderBundleIdentifier: self.bundleId) { manager, error in
                if let manager = manager {
                    self.vpnManager = manager
                }
                completion(manager, error)
            }
        }
    }
    
    private func logFile() -> URL? {
        guard let sharedFolderURL = FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: appGroup) else {
            log.error("Cannot obtain shared folder URL for appGroup", category: .app, metadata: ["appGroupId": "\(appGroup)", "protocol": "WireGuard"])
            return nil
        }
        return sharedFolderURL.appendingPathComponent(CoreAppConstants.LogFiles.wireGuard)
    }

    /// Tries to flush logs to a logfile. Call handler with true if flush succeeded or false otherwise.
    public func flushLogs(responseHandler: @escaping (_ success: Bool) -> Void) {
        vpnProviderManager(for: .status) { manager, error in
            guard let manager = manager, let connection = manager.vpnConnection as? NETunnelProviderSessionWrapper else {
                responseHandler(false)
                return
            }
            do {
                try connection.sendProviderMessage(WireguardProviderRequest.flushLogsToFile.asData) { _ in
                    responseHandler(true)
                }
            } catch {
                responseHandler(false)
            }
        }
    }
}

public extension StoredWireguardConfig {
    init(vpnManagerConfig: VpnManagerConfiguration,
         wireguardConfig: WireguardConfig) {
        self.init(wireguardConfig: wireguardConfig,
                  clientPrivateKey: vpnManagerConfig.clientPrivateKey,
                  serverPublicKey: vpnManagerConfig.serverPublicKey,
                  entryServerAddress: vpnManagerConfig.entryServerAddress,
                  ports: vpnManagerConfig.ports,
                  timestamp: Date())
    }
}
