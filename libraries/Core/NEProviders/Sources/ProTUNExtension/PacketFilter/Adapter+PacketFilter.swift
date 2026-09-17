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
    import Network
    import NetworkExtension
    import NetworkingErgonomics
    import os
    import enum VPNCoreCommon.ProTUNConfigurationCoder
    import struct VPNCoreTypes.ProTUNConfiguration

    extension ProTUNAdapter {
        /// Rebuilds the packet filter policy from the saved provider configuration and the tunnel descriptor, then
        /// hands it to the coordinator. The adapter calls this wherever it changes either input.
        func refreshPacketFilterPolicy() {
            packetFilterCoordinator.update(policy: currentPacketFilterPolicy())
        }

        private func currentPacketFilterPolicy() -> PacketFilterPolicy {
            let protocolConfiguration = packetTunnelProvider?.protocolConfiguration as? NETunnelProviderProtocol
            let allowsLocalNetworks = protocolConfiguration?.excludeLocalNetworks ?? false

            // If there is no active tunnel interface or no VPN protocol configuration present, fail closed and block
            // all traffic according to the LAN settings.
            guard let tunnelFd, let protocolConfiguration else {
                return .emptyPolicy(allowsLocalNetworks: allowsLocalNetworks)
            }

            // Resolve the tunnel descriptor to its interface index so we can quickly check whether a packet is going
            // over the VPN from the packet filter. No index means no interface, in which case we block all traffic.
            guard let tunnelInterfaceIndex = interfaceIndex(ofTunnelDescriptor: tunnelFd) else {
                Logger.packetFilter.error("The tunnel descriptor has no interface index, blocking without a tunnel")
                return .emptyPolicy(allowsLocalNetworks: allowsLocalNetworks)
            }

            do {
                let configuration = try ProTUNConfigurationCoder.decode(from: protocolConfiguration)
                return PacketFilterPolicy(
                    configuration: configuration,
                    tunnelInterfaceIndex: tunnelInterfaceIndex,
                    allowsLocalNetworks: allowsLocalNetworks
                )
            } catch {
                Logger.packetFilter.error(
                    "Provider configuration failed to decode, blocking without endpoints: \(error, privacy: .public)"
                )
                return .emptyPolicy(allowsLocalNetworks: allowsLocalNetworks)
            }
        }
    }

    extension PacketFilterPolicy {
        /// The filter policy for a tunnel.
        init(configuration: ProTUNConfiguration, tunnelInterfaceIndex: UInt32, allowsLocalNetworks: Bool) {
            let addresses = configuration.uniquePeerAddresses
            self.init(
                tunnelInterfaceIndex: tunnelInterfaceIndex,
                endpointsV4: Set(addresses.compactMap { IPv4Address($0) }),
                endpointsV6: Set(addresses.compactMap { IPv6Address($0) }),
                allowsLocalNetworks: allowsLocalNetworks
            )
        }
    }
#endif
