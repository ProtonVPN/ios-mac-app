//
//  Created on 23/06/2026 by Max Kupetskyi.
//
//  Copyright (c) 2026 Proton AG
//
//  Proton VPN is free software: you can redistribute it and/or modify
//  it under the terms of the GNU General Public License as published by
//  the Free Software Foundation, either version 3 of the License, or
//  (at your option) any later version.
//
//  Proton VPN is distributed in the hope that it will be useful,
//  but WITHOUT ANY WARRANTY; without even the implied warranty of
//  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
//  GNU General Public License for more details.
//
//  You should have received a copy of the GNU General Public License
//  along with Proton VPN.  If not, see <https://www.gnu.org/licenses/>.

import ConnectionShared
import let CoreConnection.log
import Dependencies
import Domain
import NetworkExtension

// Backing operations for the `VPNTunnelControl` dependency (see its docs for the use cases). They
// live in this module because `tunnelManager` and `vpnManagerRepository` are internal to it.

/// Stops the active VPN tunnel (including the zero-peer kill switch tunnel) and disables on-demand
/// so it won't auto-restart. Finding no tunnel to stop counts as success.
public func stopActiveVPNTunnel() async throws {
    @Dependency(\.tunnelManager) var tunnelManager
    do {
        try await tunnelManager.stopTunnel()
    } catch TunnelManagerError.missingConfiguration {
        // Nothing is running, so the caller's goal (no tunnel, no blackhole) is already met.
    }
}

/// Switches the live tunnel to a peerless zero-peer blackhole in place, so Advanced kill switch keeps blocking
/// after sign-out without tearing the tunnel down
public func enterZeroPeerBlockingTunnel() async throws {
    @Dependency(\.tunnelManager) var tunnelManager
    @Dependency(\.vpnManagerRepository) var managerRepository

    // Zero-peer mode is a location update with no peers. Keep the spec already recorded in the saved
    // configuration, so only the peers (and the pinned kill switch flag) change.
    guard let configuration = try await managerRepository.manager(for: .wireGuard).protocolConfiguration as? NETunnelProviderProtocol else {
        log.error("Entering zero-peer blocking without a provider configuration; using a default connection spec", category: .connection)
        return try await requestZeroPeerUpdate(spec: ConnectionSpec(), tunnelManager: tunnelManager)
    }

    let spec: ConnectionSpec
    do {
        spec = try configuration.connectionSpec ?? ConnectionSpec()
    } catch {
        log.error("Failed to decode the recorded connection spec, using a default one: \(error)", category: .connection)
        spec = ConnectionSpec()
    }
    try await requestZeroPeerUpdate(spec: spec, tunnelManager: tunnelManager)
}

private func requestZeroPeerUpdate(spec: ConnectionSpec, tunnelManager: any TunnelManager) async throws {
    _ = try await tunnelManager.sendProTUN(request: .init(payload: .updateConfiguration(.zeroPeer(using: spec))))
}
