//
//  WireguardProtocolFactory.swift
//  LegacyCommon
//
//  Created by Jaroslav on 2021-05-17.
//  Copyright © 2021 Proton Technologies AG. All rights reserved.
//

import CommonNetworking
import Dependencies
import DependenciesMacros
import Domain
import ExtensionIPC
import Foundation
import NetworkExtension
import ProtonCoreFeatureFlags
import Sharing
import VPNAppCore
import VPNShared

@DependencyClient
public struct WireguardProtocolManager {
    public var create: @Sendable (_ configuration: VpnManagerConfiguration) throws -> NEVPNProtocol
    public var vpnProviderManager: @Sendable (_ for: VpnProviderManagerRequirement, _ completion: @escaping (NEVPNManagerWrapper?, Error?) -> Void) -> Void
    public var vpnProviderManagerAsync: @Sendable (_ for: VpnProviderManagerRequirement) async throws -> NEVPNManagerWrapper
    public var logs: @Sendable (_ completion: @escaping (String?) -> Void) -> Void
}

extension WireguardProtocolManager: VpnProtocolFactory {
    public func create(_ configuration: VpnManagerConfiguration) throws -> NEVPNProtocol {
        try create(configuration)
    }

    public func vpnProviderManager(for requirement: VpnProviderManagerRequirement) async throws -> NEVPNManagerWrapper {
        try await vpnProviderManagerAsync(requirement)
    }
}

// MARK: - DependencyKey

extension WireguardProtocolManager: DependencyKey {
    public static func liveValue(bundleId: String, appGroup: String) -> WireguardProtocolManager {
        actor VPNManagerCache {
            private(set) var vpnManager: NETunnelProviderManagerWrapper?

            func setManager(_ manager: NETunnelProviderManagerWrapper?) {
                vpnManager = manager
            }
        }

        let cache = VPNManagerCache()

        @Dependency(\.neTunnelProviderManager) var neVpnManager

        @Sendable
        func logFile() -> URL? {
            guard let sharedFolderURL = FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: appGroup) else {
                log.error("Cannot obtain shared folder URL for appGroup", category: .app, metadata: ["appGroupId": "\(appGroup)", "protocol": "WireGuard"])
                return nil
            }
            return sharedFolderURL.appendingPathComponent(DomainConstants.LogFiles.wireGuard)
        }

        return WireguardProtocolManager(
            create: { configuration in
                let protocolConfiguration = NETunnelProviderProtocol()
                protocolConfiguration.providerBundleIdentifier = bundleId
                protocolConfiguration.serverAddress = configuration.entryServerAddress
                protocolConfiguration.connectedLogicalId = configuration.serverId
                protocolConfiguration.connectedServerIpId = configuration.ipId

                // Future: remove this flag and the plumbing that goes all the way to CertificateRefreshRequest.withPublicKey
                // in the NEHelper module and in `parameters` in the CertificateRequest struct in LegacyCommon. (VPNAPPL-2134)
                // Don't remove this FF until we fix the root cause! (VPNAPPL-2766)
                if FeatureFlagsRepository.shared.isEnabled(VPNFeatureFlagType.certificateRefreshForceRenew, reloadValue: true) {
                    protocolConfiguration.unleashFeatureFlagShouldForceConflictRefresh = true
                }

                #if os(macOS)
                    if VPNFeatureFlagType.plutoniumMacOS.enabled {
                        @SharedReader(.plutoniumFeature) var feature: PlutoniumFeatureToggle

                        // The default value of `captureTrafficAutomatically` is true. so we need to set it to false only if we needed to.
                        if case .enabled(.inclusion) = feature {
                            protocolConfiguration.providerConfiguration = [
                                WireGuardProviderConfig.captureTrafficAutomatically(false),
                            ].asDictionary
                        }
                    }
                #endif

                return protocolConfiguration
            },
            vpnProviderManager: { requirement, completion in
                Task {
                    guard requirement == .status, let vpnManager = await cache.vpnManager else {
                        neVpnManager.getManagerForBundleSync(bundleId) { manager, error in
                            if let manager {
                                Task {
                                    await cache.setManager(manager)
                                    completion(manager, error)
                                }
                            }
                        }
                        return
                    }
                    completion(vpnManager, nil)
                }
            },
            vpnProviderManagerAsync: { requirement in
                guard requirement == .status, let vpnManager = await cache.vpnManager else {
                    let vpnManager = try await neVpnManager.getManagerForBundle(bundleId)
                    await cache.setManager(vpnManager)
                    return vpnManager
                }
                return vpnManager
            },
            logs: { completion in
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
        )
    }

    public static let liveValue: WireguardProtocolManager = {
        let bundleId = DomainConstants.NetworkExtensions.wireguard
        let appGroup = DomainConstants.AppGroups.main
        return liveValue(bundleId: bundleId, appGroup: appGroup)
    }()
}

// MARK: - DependencyValues Extension

public extension DependencyValues {
    var wireguardProtocolManager: WireguardProtocolManager {
        get { self[WireguardProtocolManager.self] }
        set { self[WireguardProtocolManager.self] = newValue }
    }
}

public extension StoredWireguardConfig {
    init(
        vpnManagerConfig: VpnManagerConfiguration,
        wireguardConfig: WireguardConfig
    ) {
        self.init(
            wireguardConfig: wireguardConfig,
            clientPrivateKey: vpnManagerConfig.clientPrivateKey,
            serverPublicKey: vpnManagerConfig.serverPublicKey,
            entryServerAddress: vpnManagerConfig.entryServerAddress,
            ports: vpnManagerConfig.ports,
            timestamp: Date()
        )
    }
}

// Typed provider configurations for WireGuard
enum WireGuardProviderConfig {
    case captureTrafficAutomatically(Bool)

    var key: String {
        switch self {
        case .captureTrafficAutomatically: "captureTrafficAutomatically"
        }
    }

    var value: Any {
        switch self {
        case let .captureTrafficAutomatically(flag): flag
        }
    }
}

extension [WireGuardProviderConfig] {
    var asDictionary: [String: Any] {
        reduce(into: [String: Any]()) { dict, setting in
            dict[setting.key] = setting.value
        }
    }
}

#if DEBUG
    extension WireguardProtocolManager {
        static func testManager(
            bundleId: String,
            factory: NETunnelProviderManagerFactoryMock
        ) -> WireguardProtocolManager {
            let manager = factory.makeNewManager()

            return WireguardProtocolManager(
                create: { configuration in
                    let config = NETunnelProviderProtocol()
                    config.providerBundleIdentifier = bundleId
                    config.serverAddress = configuration.entryServerAddress
                    config.connectedLogicalId = configuration.serverId
                    config.connectedServerIpId = configuration.ipId
                    return config
                },
                vpnProviderManager: { _, completion in
                    completion(manager, nil)
                },
                vpnProviderManagerAsync: { _ in
                    manager
                },
                logs: { _ in }
            )
        }
    }
#endif
