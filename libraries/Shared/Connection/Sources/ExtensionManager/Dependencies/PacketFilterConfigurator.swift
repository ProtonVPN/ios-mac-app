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
    import CoreConnection
    import Dependencies
    import DependenciesMacros
    import Domain
    import NetworkExtension
    import Strings

    /// Manages the macOS packet filter configuration for Advanced kill switch. The filter provider in the ProTUN system
    /// extension keeps dropping non-tunnel packets after the VPN configuration is disabled or removed.
    @DependencyClient
    package struct PacketFilterConfigurator: Sendable {
        /// Brings the saved filter configuration in line with the kill switch level.
        package var reconcile: @Sendable (_ killSwitchMode: KillSwitchMode) async throws -> Void
    }

    extension PacketFilterConfigurator: DependencyKey {
        package static let liveValue = PacketFilterConfigurator(
            reconcile: { killSwitchMode in
                @Dependency(\.bundleIDClient) var bundleIDClient
                let providerBundleIdentifier = bundleIDClient.bundleIdentifier(.wireGuard)

                let manager = NEFilterManager.shared()
                try await manager.loadFromPreferences()

                guard killSwitchMode.isAdvanced else {
                    guard manager.providerConfiguration != nil || manager.isEnabled else { return }
                    try await manager.removeFromPreferences()
                    return
                }

                let current = manager.providerConfiguration
                if manager.isEnabled,
                   current?.filterPackets == true,
                   current?.filterPacketProviderBundleIdentifier == providerBundleIdentifier {
                    return
                }

                let configuration = NEFilterProviderConfiguration()
                configuration.filterPackets = true
                configuration.filterSockets = false
                configuration.filterPacketProviderBundleIdentifier = providerBundleIdentifier
                manager.providerConfiguration = configuration
                manager.localizedDescription = "Proton VPN (\(Localizable.killSwitch))"
                manager.grade = .firewall
                manager.isEnabled = true
                try await manager.saveToPreferences()
            }
        )

        package static let testValue = PacketFilterConfigurator(reconcile: { _ in })
    }

    package extension DependencyValues {
        var packetFilterConfigurator: PacketFilterConfigurator {
            get { self[PacketFilterConfigurator.self] }
            set { self[PacketFilterConfigurator.self] = newValue }
        }
    }
#endif
