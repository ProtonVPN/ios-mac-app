//
//  Created on 01/06/2026.
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
import NetworkExtension

enum ConfigurationUpdater {
    // TODO: do this cleanly AND TEST IF IT WORKS PROPERLY IN RELEASE MODE
    static func setLocalizedDescriptionToProTUNConfiguration(_: String) async throws {
        let managers = try await NETunnelProviderManager.loadAllFromPreferences()
        let proTUNManager = managers.first {
            ($0.protocolConfiguration as? NETunnelProviderProtocol)?
                .providerBundleIdentifier == "ch.protonmail.vpn.ProTUN-Extension-Mobile"
        }!
        proTUNManager.localizedDescription = "\(Date.now)"
        // proTUNManager.isOnDemandEnabled = false
        try await proTUNManager.saveToPreferences()
    }
}
