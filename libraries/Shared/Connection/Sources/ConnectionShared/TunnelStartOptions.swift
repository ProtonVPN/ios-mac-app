//
//  Created on 27/08/2026 by Chris Janusiewicz.
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

/// Keys of the options dictionary the app hands to `startVPNTunnel(options:)`.
public enum TunnelStartOptions {
    /// Marks a start the app asked for. The system passes no options when it starts the tunnel itself (an on-demand
    /// rule, Settings or Control Centre), so the extension uses this key to tell the two apart.
    public static let activationAttemptId = "activationAttemptId"
}
