//
//  Created on 21/08/2026.
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

#if os(macOS)
    import Dependencies
    import Network
    import NetworkExtension
    import os

    /// Used with Advanced Kill Switch to enforce dropping all packets not specifically bound for the tunnel, one layer
    /// deeper in the networking stack than .includeAllNetworks.
    open class ProTUNPacketFilterProvider: NEFilterPacketProvider {
        @Dependency(\.packetFilterCoordinator) private var coordinator

        override open func startFilter() async throws {
            coordinator.filterDidStart()
            packetHandler = { [coordinator] _, interface, direction, bytes, length in
                coordinator.verdict(
                    interfaceIndex: nw_interface_get_index(interface),
                    interfaceType: nw_interface_get_type(interface),
                    direction: direction,
                    packet: UnsafeRawBufferPointer(start: bytes, count: length).bytes
                )
            }
        }

        override open func stopFilter(with reason: NEProviderStopReason) async {
            Logger.packetFilter.info("Stopping packet filter with reason: \(reason, privacy: .public)")
            packetHandler = nil
            coordinator.filterDidStop()
        }
    }
#endif
