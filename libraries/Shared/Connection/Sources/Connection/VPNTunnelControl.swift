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
import ExtensionManager

/// currently used only for disabling advanced KS from the login screen.
/// revisit when we have more TCA, and if connection state is moved out of HomeFeature/SidebarFeature
public struct VPNTunnelControl: Sendable {
    /// Stops the active tunnel (including the zero-peer kill switch tunnel) and disables on-demand so it
    /// won't auto-restart
    public var stop: @Sendable () async throws -> Void

    public init(stop: @escaping @Sendable () async throws -> Void) {
        self.stop = stop
    }
}

extension VPNTunnelControl: DependencyKey {
    public static let liveValue = VPNTunnelControl(stop: {
        try await stopActiveVPNTunnel()
    })

    public static let testValue = VPNTunnelControl(stop: {})
}

public extension DependencyValues {
    var vpnTunnelControl: VPNTunnelControl {
        get { self[VPNTunnelControl.self] }
        set { self[VPNTunnelControl.self] = newValue }
    }
}
