// SPDX-License-Identifier: MIT
// Copyright © 2018-2020 WireGuard LLC. All Rights Reserved.

import NetworkExtension
import WireGuardKit
import WireGuardLogging

enum PacketTunnelProviderError: String, Error {
    case savedProtocolConfigurationIsInvalid
    case dnsResolutionFailure
    case couldNotStartBackend
    case couldNotDetermineFileDescriptor
    case couldNotSetNetworkSettings
    case adapterHasInvalidState
}

extension NETunnelProviderProtocol {
    /// This is needed in case the user updates their app while connected, without
    /// opening it and reconnecting.
    func tunnelConfigFromOldData(
        _ data: Data,
        called name: String?
    ) -> TunnelConfiguration? {
        guard let config = String(data: data, encoding: .utf8),
              config.starts(with: "[Interface]") else {
            wg_log(.info, message: "Stored WireGuard config is corrupted or of unknown format.")
            return nil
        }
        return try? TunnelConfiguration(fromWgQuickConfig: config, called: name)
    }
}
