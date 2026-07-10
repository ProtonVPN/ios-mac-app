//
//  Created on 26/05/2026 by Max Kupetskyi.
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

import ConnectionInventory
import Dependencies
import Domain
import Sharing
import VPNAppCore

/// Migrated logic from `VpnGateway.quickConnect`into the new connection layer.
///
/// Use this any time the app wants to issue a "Quick Connect" — i.e. a connection that should
/// honour the user's saved Quick Connect profile when available, and otherwise fall back to
/// fastest (respecting Secure Core toggle and free-tier rules). Replaces
/// `vpnGateway.quickConnect(trigger:)` whose call sites previously did this resolution inside
/// `VpnGateway`.
///
/// Callers (e.g. `MaintenanceManagerHelper`, `AppDelegateService` deep-link handlers) used to
/// pass `propertiesManager.lastConnectionIntent` directly, which is **not** equivalent — that
/// reproduces the user's last *destination*, not their Quick Connect preference.
public enum QuickConnectIntent {
    /// Resolves the `(spec, protocol)` that the new layer should connect with.
    public static func resolve() -> (spec: ConnectionSpec, connectionProtocol: ConnectionProtocol?) {
        @Dependency(\.profileAuthorizer) var profileAuthorizer
        @SharedReader(.connectionProtocol) var connectionProtocol
        @SharedReader(.userTier) var userTier
        @SharedReader(.secureCoreToggle) var secureCoreToggle
        @Dependency(\.profileManager) var profileManager

        // 1) User has a Quick Connect profile saved and is authorized to use profiles → use it.
        if let qcProfile = profileManager.quickConnectProfile(), profileAuthorizer.canUseProfiles {
            return (qcProfile.connectionSpec(trigger: nil), qcProfile.connectionProtocol)
        }

        // 2) Otherwise fall back to fastest with Secure Core / free-tier accommodations.
        let isFreeTier = userTier.isFreeTier
        let spec = SecureCoreConnectionSpecResolver.fastestSpec(
            secureCoreEnabled: secureCoreToggle,
            connectedExitCountryCode: nil,
            isFreeTier: isFreeTier
        )
        return (spec, connectionProtocol)
    }
}

public extension ConnectionCommandClient {
    /// Sends a `.connect` command resolved through `QuickConnectIntent`. Use this in place of
    /// the legacy `vpnGateway.quickConnect(trigger:)` call.
    func quickConnect(trigger: UserInitiatedVPNChange.VPNTrigger) {
        let (spec, connectionProtocol) = QuickConnectIntent.resolve()
        send(.connect(spec, connectionProtocol, trigger))
    }
}
