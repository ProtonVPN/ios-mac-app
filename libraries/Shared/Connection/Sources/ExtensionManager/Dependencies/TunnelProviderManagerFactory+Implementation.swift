//
//  Created on 31/05/2024.
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

import class NetworkExtension.NETunnelProviderManager

import let ConnectionFoundations.log

extension TunnelProviderManagerFactory {

    static var liveValue: TunnelProviderManagerFactory {
        .init(
            createNewManager: {
                log.info("Creating new Tunnel Provider Manager")
                let manager = NETunnelProviderManager()
                manager.localizedDescription = "Proton VPN Tunnel"
                return manager
            },
            removeManagers: {
                let managers = try await NETunnelProviderManager.loadAllFromPreferences()

                var errors: [Error] = []
                for manager in managers {
                    do {
                        try await manager.removeFromPreferences()
                    } catch {
                        errors.append(error)
                    }
                }

                guard errors.isEmpty else {
                    throw TunnelProviderManagerError.removalFailure(errors: errors)
                }
            },
            loadManagersFromPreferences: {
                return try await NETunnelProviderManager.loadAllFromPreferences()
            }
        )
    }
}

enum TunnelProviderManagerError: Error {
    case removalFailure(errors: [Error])
}
