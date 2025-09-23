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
import Dependencies
import Foundation
import Network
import VPNAppCore

enum NWInterfaceHelpers {
    private nonisolated(unsafe) static var networkHandle: UnsafeMutableRawPointer?
    private nonisolated(unsafe) static var createWithIndex: (@convention(c) (UInt32) -> nw_interface_t?)?

    static func retrieveInterface(with index: Int) -> nw_interface_t? {
        if networkHandle == nil {
            networkHandle = dlopen("/System/Library/Frameworks/Network.framework/Network", RTLD_LAZY)
            if let symbol = dlsym(networkHandle, "nw_interface_create_with_index") {
                createWithIndex = unsafeBitCast(symbol, to: (@convention(c) (UInt32) -> nw_interface_t?).self)
            }
        }
        return createWithIndex?(UInt32(index))
    }
}

extension NWInterface {
    /// Find network interface by exact interface name
    static func findBy(name interfaceName: String?) async -> NWInterface? {
        guard let interfaceName else {
            return nil
        }
        @Dependency(\.nwPathStream) var nwPathStream

        let pathStream = nwPathStream()

        return await pathStream
            .compactMap { path in
                path.availableInterfaces
                    .first { $0.name == interfaceName }
            }
            .first { _ in true }
    }

    /// Find the internet interface (the interface after the VPN interface that has internet access)
    /// The next network interface after WireGuard accommodates any potential network service reorderings
    /// made by the user in macOS network preferences.
    /// Returns an AsyncStream that continuously provides updates when the internet interface changes
    static func findInternetInterface(vpnInterfaceName: String) -> AsyncStream<NWInterface?> {
        @Dependency(\.nwPathStream) var nwPathStream

        let pathStream = nwPathStream()

        return pathStream.map { path in
            // Find the interface that comes after the VPN interface
            var foundVPNInterface = false

            for interface in path.availableInterfaces {
                if foundVPNInterface {
                    // Check if this interface has internet access
                    if interface.type != .loopback, path.status == .satisfied {
                        return interface
                    }
                }

                if interface.name == vpnInterfaceName {
                    foundVPNInterface = true
                }
            }
            return nil
        }
        .eraseToStream()
    }

    /// Monitor for a specific network interface by name
    /// Returns an AsyncStream that continuously provides updates on the interface availability
    /// When the interface is available, it returns the interface
    /// When the interface is not available, it returns nil
    static func monitorInterface(name interfaceName: String) -> AsyncStream<NWInterface?> {
        @Dependency(\.nwPathStream) var nwPathStream

        let pathStream = nwPathStream()

        return pathStream.map { path in
            path.availableInterfaces
                .first { $0.name == interfaceName }
        }
        .eraseToStream()
    }
}
