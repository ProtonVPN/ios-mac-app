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
import Dependencies
import Domain
import NetworkExtension

/// Stops the active VPN tunnel (including the zero-peer kill switch tunnel) and disables on-demand so it won't auto-restart.
/// revisit when we have more TCA, and if connection state is moved out of HomeFeature/SidebarFeature
public func stopActiveVPNTunnel() async throws {
    @Dependency(\.tunnelManager) var tunnelManager
    try await tunnelManager.stopTunnel()
}

/// Switches the live tunnel to a peerless zero-peer blackhole in place, so Advanced kill switch keeps blocking
/// after sign-out without tearing the tunnel down
public func enterZeroPeerBlockingTunnel() async throws {
    @Dependency(\.tunnelManager) var tunnelManager
    @Dependency(\.vpnManagerRepository) var managerRepository

    // Zero-peer mode is a location update with no peers. Keep the spec already recorded in the saved
    // configuration, so only the peers (and the pinned kill switch flag) change.
    let configuration = try await managerRepository.manager(for: .wireGuard).protocolConfiguration as? NETunnelProviderProtocol
    let spec = ((try? configuration?.connectionSpec) ?? nil) ?? ConnectionSpec()
    let update = ConnectionUpdate(location: .init(spec: spec, peers: []), killSwitch: true)
    _ = try await tunnelManager.sendProTUN(request: .init(payload: .updateConfiguration(update)))
}
