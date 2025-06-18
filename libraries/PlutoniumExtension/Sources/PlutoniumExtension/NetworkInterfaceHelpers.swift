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

import Foundation
import Network

extension NWInterface {
    static func findWireGuardInterface(expectedIP: String) async -> NWInterface? {
        await withCheckedContinuation { continuation in
            let monitor = NWPathMonitor()
            monitor.pathUpdateHandler = { path in
                for interface in path.availableInterfaces {
                    // look for any "other" interface named "utun..."
                    if interface.type == .other, interface.name.hasPrefix("utun") {
                        if interface.hasIPv4Address(expectedIP) {
                            continuation.resume(returning: interface)
                            monitor.cancel()
                            return
                        }
                    }
                }
                // keep waiting until utun comes up with that IP
                // TODO: Add a timeout mechanism.
            }
            monitor.start(queue: .global(qos: .background))
        }
    }

    static func findInternetInterface() async -> NWInterface? {
        await withCheckedContinuation { continuation in
            let monitor = NWPathMonitor()
            let queue = DispatchQueue(label: "InternetInterfaceMonitor")

            monitor.pathUpdateHandler = { path in
                // Find the primary interface that has internet connectivity
                // Prioritize: Ethernet -> WiFi -> Cellular
                var bestInterface: NWInterface?
                var bestPriority = 0

                for interface in path.availableInterfaces {
                    var priority = 0

                    switch interface.type {
                    case .wiredEthernet:
                        priority = 3
                    case .wifi:
                        priority = 2
                    case .cellular:
                        priority = 1
                    default:
                        continue
                    }

                    // Check if this interface can reach the internet
                    let pathToInternet = NWPath.Status.satisfied
                    if path.status == pathToInternet, priority > bestPriority {
                        bestInterface = interface
                        bestPriority = priority
                    }
                }

                monitor.cancel()
                continuation.resume(returning: bestInterface)
            }

            monitor.start(queue: queue)
        }
    }

    func hasIPv4Address(_: String) -> Bool {
        // TODO: Implement this
        true
    }
}
