//
//  Created on 19/05/2025 by Shahin Katebi.
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
import NetworkExtension
@preconcurrency import VPNAppCore

actor FlowHandlingManager {
    // MARK: Stored properties

    private let appIDs: Set<String>
    private let pluginIDs: Set<String>
    private let ipSet: Set<String>
    private let networkInterface: NWInterface

    // Handler storage

    private var activeTCPHandlers: Set<TCPFlowHandler> = []
    private var activeUDPHandlers: Set<UDPFlowHandler> = []

    // MARK: Initialisation

    init(vpnNetworkInterfaceName: String) async throws {
        @SharedReader(.plutoniumFeature) var feature: PlutoniumFeatureToggle

        guard case let .enabled(mode) = feature else {
            log.warning("Plutonium disabled. Should not reach here.")
            throw PlutoniumError.featureDisabled
        }

        switch mode {
        case .exclusion:
            @SharedReader(.exclusionActivated) var exclusionActivated: PlutoniumActivated

            self.appIDs = Set(exclusionActivated.apps.map(\.bundleIdentifier))
            let plugins = exclusionActivated.apps.flatMap(\.plugins)
            self.pluginIDs = Set(plugins.map(\.bundleIdentifier))
            self.ipSet = Set(exclusionActivated.ips)

            guard let networkInterface = await NWInterface.findInternetInterface(vpnInterfaceName: vpnNetworkInterfaceName) else {
                log.error("No internet interface found before VPN with interface name \(vpnNetworkInterfaceName).")
                throw PlutoniumError.vpnInterfaceNotFound
            }
            self.networkInterface = networkInterface
            log.info("FlowHandlingManager initialised in exclusion mode with \(appIDs.count) excluded apps, \(ipSet.count) excluded IPs and internet interface \(networkInterface).")

        case .inclusion:
            @SharedReader(.inclusionActivated) var inclusionActivated: PlutoniumActivated

            self.appIDs = Set(inclusionActivated.apps.map(\.bundleIdentifier))
            let plugins = inclusionActivated.apps.flatMap(\.plugins)
            self.pluginIDs = Set(plugins.map(\.bundleIdentifier))
            self.ipSet = Set(inclusionActivated.ips)

            guard let networkInterface = await NWInterface.findBy(name: vpnNetworkInterfaceName) else {
                log.error("No VPN interface found with name \(vpnNetworkInterfaceName).")
                throw PlutoniumError.vpnInterfaceNotFound
            }
            self.networkInterface = networkInterface
            log.info("FlowHandlingManager initialised in inclusion mode with \(appIDs.count) included apps, \(ipSet.count) included IPs and VPN interface \(networkInterface).")
        }
    }

    private func add(_ handler: TCPFlowHandler) {
        activeTCPHandlers.insert(handler)

        // Start with cleanup callback
        handler.start { [weak self] in
            guard let self else { return }
            await self.remove(handler)
        }
    }

    private func add(_ handler: UDPFlowHandler) {
        activeUDPHandlers.insert(handler)

        // Start with cleanup callback
        handler.start { [weak self] in
            guard let self else { return }
            await self.remove(handler)
        }
    }

    // MARK: - Removal helpers

    private func remove(_ handler: TCPFlowHandler) {
        activeTCPHandlers.remove(handler)
    }

    private func remove(_ handler: UDPFlowHandler) {
        activeUDPHandlers.remove(handler)
    }

    private func cleanup() {
        for handler in activeTCPHandlers {
            handler.stop()
        }
        activeTCPHandlers.removeAll()

        for handler in activeUDPHandlers {
            handler.stop()
        }
        activeUDPHandlers.removeAll()
    }

    nonisolated func actionForApp(identifier: String) -> RouteAction {
        let found = appIDs.contains(identifier) || pluginIDs.contains(identifier)
        return found ? .forward(to: networkInterface) : .dontHandle
    }

    private nonisolated func routeForIP(_ ip: String) -> RouteAction {
        let found = ipSet.contains(ip)
        return found ? .forward(to: networkInterface) : .dontHandle
    }

    // MARK: - Public registration helpers

    /// Track a TCP flow handler.
    nonisolated func register(_ handler: TCPFlowHandler) {
        Task { await add(handler) }
    }

    /// Track a UDP flow handler.
    nonisolated func register(_ handler: UDPFlowHandler) {
        Task { await add(handler) }
    }

    nonisolated func cleanupAllHandlers() {
        Task { await cleanup() }
    }

    // MARK: Helper

    enum RouteAction {
        case dontHandle
        case forward(to: NWInterface)
    }
}
