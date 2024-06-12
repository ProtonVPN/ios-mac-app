//
//  Created on 30/05/2024.
//
//  Copyright (c) 2024 Proton AG
//
//  ProtonVPN is free software: you can redistribute it and/or modify
//  it under the terms of the GNU General Public License as published by
//  the Free Software Foundation, either version 3 of the License, or
//  (at your option) any later version.
//
//  ProtonVPN is distributed in the hope that it will be useful,
//  but WITHOUT ANY WARRANTY; without even the implied warranty of
//  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
//  GNU General Public License for more details.
//
//  You should have received a copy of the GNU General Public License
//  along with ProtonVPN.  If not, see <https://www.gnu.org/licenses/>.

import Foundation

extension TunnelProviderManager {
    var providerBundleIdentifier: String? { vpnProtocolConfiguration?.providerBundleIdentifier }
}

extension TunnelProviderManagerFactory {

    /// Loads an existing `TunnelProviderManager`, or creates and loads a new manager.
    func loadManager(forProviderBundleID bundleID: String) async throws -> TunnelProviderManager {
        let managers = try await loadFromPreferences()
        let existingManagerWithMatchingBundleID = managers
            .first { $0.providerBundleIdentifier == bundleID }

        if let existingManagerWithMatchingBundleID {
            return existingManagerWithMatchingBundleID
        }

        let newManager = create()
        try await newManager.loadFromPreferences()
        return newManager
    }
}
