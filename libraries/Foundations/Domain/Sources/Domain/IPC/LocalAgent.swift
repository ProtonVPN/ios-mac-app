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
    static let localAgentToExtensionRequests: Self = .init(name: "ch.protonmail.vpn.protun.localAgentToExtensionRequests")
    static let localAgentFromExtensionEvents: Self = .init(name: "ch.protonmail.vpn.protun.localAgentFromExtensionEvents")
}

public extension IPCNotifications.Notification {
    static let extensionForkSelectorRequest: Self = .init(name: "ch.protonmail.vpn.protun.extensionForkSelectorRequest")
    static let localAgentSettings: Self = .init(name: "ch.protonmail.vpn.protun.localAgentSettings")
}
