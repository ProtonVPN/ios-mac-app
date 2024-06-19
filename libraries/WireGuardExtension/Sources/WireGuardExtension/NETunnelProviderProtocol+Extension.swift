// SPDX-License-Identifier: MIT
// Copyright © 2018-2020 WireGuard LLC. All Rights Reserved.

import NetworkExtension
import WireGuardKit
import WireGuardLogging
import KeychainAccess
import ConnectionFoundations

enum PacketTunnelProviderError: String, Error {
    case savedProtocolConfigurationIsInvalid
    case dnsResolutionFailure
    case couldNotStartBackend
    case couldNotDetermineFileDescriptor
    case couldNotSetNetworkSettings
    case adapterHasInvalidState
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


    #if os(macOS)
    func asTunnelConfiguration(called name: String? = nil) -> TunnelConfiguration? {
        if let data = Keychain.loadWgConfig() {
            wg_log(.info, message: "Loading config directly from keychain")
            return tunnelConfigurationFromData(data, called: name)
        }
        if let passwordReference = passwordReference,
           let data = Keychain.openReference(called: passwordReference) {
            wg_log(.info, message: "Loading config from keychain by reference")
            return tunnelConfigurationFromData(data, called: name)
        }
        return nil
    }

    func tunnelConfigurationFromData(_ data: Data,
                                     called name: String?) -> TunnelConfiguration? {
        guard let storedConfig = storedWireguardConfigurationFromData(data) else {
            wg_log(.info, message: "Trying old WireGuard configuration format.")
            return tunnelConfigFromOldData(data, called: name)
        }

        let wgConfig = storedConfig.asWireguardConfiguration()
        return try? TunnelConfiguration(fromWgQuickConfig: wgConfig, called: name)
    }
    #endif

    func keychainConfigData() -> Data? {
        wg_log(.info, message: "Loading config from keychain by reference")
        
        guard let passwordReference = passwordReference,
           let data = Keychain.openReference(called: passwordReference) else {
            return nil
        }

        return data
    }

    func storedWireguardConfigurationFromData(_ data: Data) -> StoredWireguardConfig? {
        guard let version = StoredWireguardConfig.Version(rawValue: Int(data[0])) else {
            wg_log(.info, message: "No known version found for StoredWireguardConfig")
            return nil
        }

        wg_log(.info, message: "Using configuration format \(String(describing: version)).")

        guard case .v1 = version else {
            wg_log(.info, message: "Version \(version) is not yet supported.")
            return nil
        }

        let configData = data[1...]
        let decoder = JSONDecoder()
        guard let storedConfig = (try? decoder.decode(StoredWireguardConfig.self,
                                                      from: configData)) else {
            wg_log(.error, message: "Could not decode data (\(String(describing: version))")
            return nil
        }

        return storedConfig
    }

    /// This is needed in case the user updates their app while connected, without
    /// opening it and reconnecting.
    func tunnelConfigFromOldData(_ data: Data,
                                 called name: String?) -> TunnelConfiguration? {
        guard let config = String(data: data, encoding: .utf8),
            config.starts(with: "[Interface]") else {
            wg_log(.info, message: "Stored WireGuard config is corrupted or of unknown format.")
            return nil
        }
        return try? TunnelConfiguration(fromWgQuickConfig: config, called: name)
    }

    func destroyConfigurationReference() {
        guard let ref = passwordReference else { return }
        Keychain.deleteReference(called: ref)
    }

    func verifyConfigurationReference() -> Bool {
        guard let ref = passwordReference else { return false }
        return Keychain.verifyReference(called: ref)
    }
}
