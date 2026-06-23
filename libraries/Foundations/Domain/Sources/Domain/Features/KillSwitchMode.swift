//
//  Created on 22/06/2026 by Max Kupetskyi.
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

import Foundation

/// The three kill switch protection levels, matching the cross-platform (Windows/Linux) model.
///
/// - `off`: no protection.
/// - `standard`: after a successful connection, block traffic on an *unexpected* drop until the VPN is
///   restored. Released on user-initiated disconnect, logout, or switching to `off`.
/// - `advanced`: block *all* non-VPN traffic at all times (including before app launch, across reboots and
///   after intentional disconnects). Activates immediately on enabling and persists until the user switches
///   to `off`/`standard`.
public enum KillSwitchMode: Int, CaseIterable, Codable, Sendable {
    case off = 0
    case standard = 1
    case advanced = 2

    /// Whether any kill switch protection is enabled (Standard or Advanced).
    public var isProtected: Bool {
        self != .off
    }

    /// Whether the Advanced level — persistent, always-on blocking — is selected.
    public var isAdvanced: Bool {
        self == .advanced
    }
}
