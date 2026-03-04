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
import class NetworkExtension.NEVPNManager

import let CoreConnection.log

extension TunnelProviderManagerFactory {
    static var liveValue: TunnelProviderManagerFactory {
        .init(
            create: { type in
                switch type {
                case .ike:
                    return NEVPNManager.shared()
                case .custom:
                    log.info("Creating new Tunnel Provider Manager")
                    return NETunnelProviderManager()
                }
            },
            removeAll: {
                let managers = try await NETunnelProviderManager.loadAllFromPreferences()

                var errors: [Error] = []
                for manager in managers {
                    do {
                        try await manager.removeFromPreferences()
                    } catch {
                        errors.append(error)
                    }
                }
                do {
                    try await NEVPNManager.shared().removeFromPreferences()
                }

                guard errors.isEmpty else {
                    throw TunnelProviderManagerError.removalFailure(errors: errors)
                }
            },
            loadFromPreferences: {
                let manager = NEVPNManager.shared()
                try await manager.loadFromPreferences()
                return try await [manager] + NETunnelProviderManager.loadAllFromPreferences()
            }
        )
    }
}

enum TunnelProviderManagerError: Error {
    case removalFailure(errors: [Error])
}
