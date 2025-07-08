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
import Dependencies
import NetworkExtension
@preconcurrency import VPNAppCore

actor FlowHandlingManager {
    // MARK: Stored properties

    private let appIDs: Set<String>
    private let pluginIDs: Set<String>
    private let ipSet: Set<String>

    /// Cached copy for internal sync access where async isn't possible.
    /// Updated inside actor only. May be slightly stale.
    private nonisolated(unsafe) var networkInterface: NWInterface?

    // Handler storage

    private var activeTCPHandlers: Set<TCPFlowHandler> = []
    private var activeUDPHandlers: Set<UDPFlowHandler> = []

    // Internet network interface monitoring for exclusion mode
    private var networkInterfaceMonitorTask: Task<Void, Never>?

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

            // Start monitoring internet interface updates
            let internetInterfaceStream = await NWInterface.findInternetInterface(vpnInterfaceName: vpnNetworkInterfaceName)
            self.networkInterfaceMonitorTask = Task { [weak self] in
                var hasInitialInterface = false
                for await interface in internetInterfaceStream {
                    await self?.updateNetworkInterface(interface)
                    if !hasInitialInterface {
                        if interface != nil {
                            log.info("FlowHandlingManager initialised in exclusion mode with \(self?.appIDs.count ?? 0) excluded apps, \(self?.ipSet.count ?? 0) excluded IPs and internet interface \(interface?.debugDescription ?? "nil").")
                            hasInitialInterface = true
                        } else {
                            log.error("No internet interface found before VPN with interface name \(vpnNetworkInterfaceName).")
                        }
                    }
                }
            }

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
            await remove(handler)
        }
    }

    private func add(_ handler: UDPFlowHandler) {
        activeUDPHandlers.insert(handler)

        // Start with cleanup callback
        handler.start { [weak self] in
            guard let self else { return }
            await remove(handler)
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

        // Cancel network interface monitoring
        networkInterfaceMonitorTask?.cancel()
        networkInterfaceMonitorTask = nil
    }

    private func updateNetworkInterface(_ interface: NWInterface?) {
        guard let interface else {
            log.warning("Internet interface is nil, ignoring update.")
            return
        }

        networkInterface = interface
        log.info("Internet interface set to \(interface)")
    }

    nonisolated func actionForApp(identifier: String) -> RouteAction {
        let found = appIDs.contains(identifier) || pluginIDs.contains(identifier)
        guard found, let interface = networkInterface else { return .dontHandle }
        return .forward(to: interface)
    }

    private nonisolated func routeForIP(_ ip: String) -> RouteAction {
        let found = ipSet.contains(ip)
        guard found, let interface = networkInterface else { return .dontHandle }
        return .forward(to: interface)
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
