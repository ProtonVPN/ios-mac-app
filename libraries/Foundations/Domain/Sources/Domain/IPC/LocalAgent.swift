//
//  Created on 20/05/2026.
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

import IPCErgonomics

public extension IPCNotifications.Notification {
    static let extensionForkSelectorRequest: Self = .init(name: "ch.protonmail.vpn.protun.extensionForkSelectorRequest")
}

public extension IPCNotifications.Notification {
    // Each of these corresponds to a `RawChannel` conveying information to the main app / other extensions.
    static let connectionData: Self = .init(name: "ch.protonmail.vpn.protun.connectionData")
    static let localAgentStats: Self = .init(name: "ch.protonmail.vpn.protun.localAgentStats")
    static let localAgentConnectionStats: Self = .init(name: "ch.protonmail.vpn.protun.localAgentConnectionStats")
    static let localAgentError: Self = .init(name: "ch.protonmail.vpn.protun.localAgentError")
    static let localAgentFeatures: Self = .init(name: "ch.protonmail.vpn.protun.localAgentFeatures")
}
