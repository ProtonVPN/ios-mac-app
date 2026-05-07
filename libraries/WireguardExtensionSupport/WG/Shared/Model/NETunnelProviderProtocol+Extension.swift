// SPDX-License-Identifier: MIT
// Copyright © 2018-2020 WireGuard LLC. All Rights Reserved.

import ConnectionShared
import Domain
import NetworkExtension
import WireGuardKit

enum PacketTunnelProviderError: String, Error {
    case savedProtocolConfigurationIsInvalid
    case dnsResolutionFailure
    case couldNotStartBackend
    case couldNotDetermineFileDescriptor
    case couldNotSetNetworkSettings
}

extension NEPacketTunnelProvider {
    static func storedWireguardConfiguration() -> StoredWireguardConfig? {
        let data: Data?
        do {
            data = try TunnelKeychainImplementation().loadWireguardConfig()
        } catch {
            log.error("Failed to read configuration from the keychain", metadata: ["error": ""])
            return nil
        }

        guard let data else {
            log.error("Keychain did not contain configuration data")
            return nil
        }

        guard let version = StoredWireguardConfig.Version(rawValue: Int(data[0])) else {
            log.info("No known version found for StoredWireguardConfig")
            return nil
        }

        log.info("Using configuration format \(String(describing: version)).")

        guard case .v1 = version else {
            log.info("Version \(version) is not yet supported.")
            return nil
        }

        let configData = data[1...]
        let decoder = JSONDecoder()
        do {
            return try decoder.decode(StoredWireguardConfig.self, from: configData)
        } catch {
            log.error("Could not decode data (\(String(describing: version)) with error: \(error)")
            return nil
        }
    }
}
