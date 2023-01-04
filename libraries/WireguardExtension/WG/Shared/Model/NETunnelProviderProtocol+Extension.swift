// SPDX-License-Identifier: MIT
// Copyright © 2018-2020 WireGuard LLC. All Rights Reserved.

import NetworkExtension
import WireGuardKit

enum PacketTunnelProviderError: String, Error {
    case savedProtocolConfigurationIsInvalid
    case dnsResolutionFailure
    case couldNotStartBackend
    case couldNotDetermineFileDescriptor
    case couldNotSetNetworkSettings
}

extension NETunnelProviderProtocol {
    convenience init?(tunnelConfiguration: TunnelConfiguration, previouslyFrom old: NEVPNProtocol? = nil) {
        self.init()

        guard let name = tunnelConfiguration.name else { return nil }
        guard let appId = Bundle.main.bundleIdentifier else { return nil }
        providerBundleIdentifier = "\(appId).WireGuardiOS-Extension"
        passwordReference = Keychain.makeReference(containing: tunnelConfiguration.asWgQuickConfig(), called: name, previouslyReferencedBy: old?.passwordReference)
        if passwordReference == nil {
            return nil
        }
        #if os(macOS)
        appUid = getuid()
        #endif

        let endpoints = tunnelConfiguration.peers.compactMap { $0.endpoint }
        if endpoints.count == 1 {
            serverAddress = endpoints[0].stringRepresentation
        } else if endpoints.isEmpty {
            serverAddress = "Unspecified"
        } else {
            serverAddress = "Multiple endpoints"
        }
    }

    func tunnelConfigurationFromData(_ data: Data,
                                     called name: String?) -> TunnelConfiguration? {
        guard let version = StoredWireguardConfig.Version(rawValue: Int(data[0])) else {
            log.info("No known version found, trying old format")
            guard let config = String(data: data, encoding: .utf8),
                  config.starts(with: "[Interface]") else {
                log.info("Tried to use old format, but couldn't decode data")
                return nil
            }
            return try? TunnelConfiguration(fromWgQuickConfig: config, called: name)
        }

        log.info("Using new configuration format (\(String(describing: version))")

        guard case .v1 = version else {
            log.info("Version \(version) is not yet supported.")
            return nil
        }

        let configData = data[1...]
        let decoder = JSONDecoder()
        guard let storedConfig = (try? decoder.decode(StoredWireguardConfig.self,
                                                      from: configData)) else {
            log.error("Could not decode data (\(String(describing: version))")
            return nil
        }

        let wgConfig = storedConfig.asWireguardConfiguration()
        return try? TunnelConfiguration(fromWgQuickConfig: wgConfig, called: name)
    }

    func asTunnelConfiguration(called name: String? = nil) -> TunnelConfiguration? {
        #if os(macOS)
        if let data = Keychain.loadWgConfig() {
            log.info("Loading config directly from keychain")
            return tunnelConfigurationFromData(data, called: name)
        }
        #endif
        if let passwordReference = passwordReference,
           let data = Keychain.openReference(called: passwordReference) {
            log.info("Loading config from keychain by reference")
            return tunnelConfigurationFromData(data, called: name)
        }
        if let oldConfig = providerConfiguration?["WgQuickConfig"] as? String {
            log.info("Loading config from provider configuration")
            return try? TunnelConfiguration(fromWgQuickConfig: oldConfig, called: name)
        }
        return nil
    }

    func destroyConfigurationReference() {
        guard let ref = passwordReference else { return }
        Keychain.deleteReference(called: ref)
    }

    func verifyConfigurationReference() -> Bool {
        guard let ref = passwordReference else { return false }
        return Keychain.verifyReference(called: ref)
    }

    @discardableResult
    func migrateConfigurationIfNeeded(called name: String) -> Bool {
        /* This is how we did things before we switched to putting items
         * in the keychain. But it's still useful to keep the migration
         * around so that .mobileconfig files are easier.
         */
        if let oldConfig = providerConfiguration?["WgQuickConfig"] as? String {
            #if os(macOS)
            providerConfiguration = ["UID": getuid()]
            #elseif os(iOS)
            providerConfiguration = nil
            #else
            #error("Unimplemented")
            #endif
            guard passwordReference == nil else { return true }
            wg_log(.debug, message: "Migrating tunnel configuration '\(name)'")
            passwordReference = Keychain.makeReference(containing: oldConfig, called: name)
            return true
        }
        #if os(macOS)
        if passwordReference != nil, appUid == nil,
           verifyConfigurationReference() {
            appUid = getuid()
            return true
        }
        #endif
        return false
    }
}
