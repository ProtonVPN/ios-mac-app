//
//  Created on 05/06/2025 by Shahin Katebi.
//
//  Copyright (c) 2025 Proton AG
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

import ComposableArchitecture
import Foundation
import Network
import VPNAppCore

extension NWInterface {
    /// Find network interface by exact interface name
    static func findBy(name interfaceName: String?) async -> NWInterface? {
        guard let interfaceName else {
            return nil
        }

        let monitor = NWPathMonitor()

        return await withCheckedContinuation { continuation in
            monitor.pathUpdateHandler = { path in
                // Simply find the interface with the exact name
                let wireguardInterface = path.availableInterfaces.first { interface in
                    interface.name == interfaceName
                }
                monitor.cancel()
                continuation.resume(returning: wireguardInterface)
            }
            monitor.start(queue: .global(qos: .userInitiated))
        }
    }

    /// Find the internet interface (the interface after the VPN interface that has internet access)
    static func findInternetInterface(vpnInterfaceName: String) async -> NWInterface? {
        let monitor = NWPathMonitor()

        return await withCheckedContinuation { continuation in
            monitor.pathUpdateHandler = { path in
                // Find the interface that comes after the VPN interface
                var foundVPNInterface = false
                var internetInterface: NWInterface?

                for interface in path.availableInterfaces {
                    if foundVPNInterface {
                        // Check if this interface has internet access
                        if interface.type != .loopback, path.status == .satisfied {
                            internetInterface = interface
                            break
                        }
                    }

                    if interface.name == vpnInterfaceName {
                        foundVPNInterface = true
                    }
                }

                monitor.cancel()
                continuation.resume(returning: internetInterface)
            }
            monitor.start(queue: .global(qos: .userInitiated))
        }
    }
}
