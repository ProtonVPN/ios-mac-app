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

import Dependencies
import DependenciesMacros
import ExtensionManager

/// Process-level tunnel control for the kill switch flows that outlive the TCA store: the login
/// screen (disable an Advanced blackhole) and sign-out (keep the blackhole up while the store is
/// torn down). Revisit once connection state moves out of HomeFeature/SidebarFeature, so these
/// flows can go through the reducer instead.
@DependencyClient
public struct VPNTunnelControl: Sendable {
    /// Stops the active tunnel (including the zero-peer kill switch tunnel) and disables on-demand so it won't
    /// auto-restart. On macOS it also removes the packet filter, so nothing keeps blocking once the tunnel is gone.
    /// Finding no tunnel to stop counts as success.
    public var stop: @Sendable () async throws -> Void

    /// Switches the live tunnel to a peerless zero-peer blackhole in place, so Advanced kill switch
    /// keeps blocking after sign-out without tearing the tunnel down.
    public var enterZeroPeerBlocking: @Sendable () async throws -> Void

    /// Has the extension discard the session state it persisted for every account, so a tunnel started
    /// outside the app - from Settings, Control Centre or an on-demand rule - can no longer connect.
    /// Throws when the message can't be delivered.
    public var clearPersistentCache: @Sendable () async throws -> Void
}

extension VPNTunnelControl: DependencyKey {
    public static let liveValue = VPNTunnelControl(
        stop: { try await stopActiveVPNTunnel() },
        enterZeroPeerBlocking: { try await enterZeroPeerBlockingTunnel() },
        clearPersistentCache: { try await clearExtensionPersistentCache() }
    )

    /// Endpoints report an issue and throw when tests exercise them without an override.
    public static let testValue = VPNTunnelControl()
}

public extension DependencyValues {
    var vpnTunnelControl: VPNTunnelControl {
        get { self[VPNTunnelControl.self] }
        set { self[VPNTunnelControl.self] = newValue }
    }
}
