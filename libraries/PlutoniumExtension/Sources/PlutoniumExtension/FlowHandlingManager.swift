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

    private static let vpnUnavailableTimeout: Duration = .seconds(5)

    private let appIDs: Set<String>
    private let pluginIDs: Set<String>
    private let ipSet: Set<String>
    private let vpnInterface: NWInterface

    /// Cached copy for internal sync access where async isn't possible.
    /// Updated inside actor only. May be slightly stale.
    private nonisolated(unsafe) var networkInterface: NWInterface?

    // Status management
    private let onVpnUnavailable: @Sendable () -> Void

    // Handler storage

    private var activeTCPHandlers: Set<TCPFlowHandler> = []
    private var activeUDPHandlers: Set<UDPFlowHandler> = []

    private var vpnNetworkInterfaceMonitorTask: Task<Void, Never>?
    private var vpnUnavailableTimeoutTask: Task<Void, Never>?

    // Internet network interface monitoring for exclusion mode
    private var networkInterfaceMonitorTask: Task<Void, Never>?

    // MARK: Initialisation

    init(vpnNetworkInterfaceName: String, onVpnUnavailable: @escaping @Sendable () -> Void) async throws {
        self.onVpnUnavailable = onVpnUnavailable

        @SharedReader(.plutoniumFeature) var feature: PlutoniumFeatureToggle

        guard case let .enabled(mode) = feature else {
            log.warning("Plutonium disabled. Should not reach here.")
            throw PlutoniumError.featureDisabled
        }

        guard let vpnInterface = await NWInterface.findBy(name: vpnNetworkInterfaceName) else {
            log.error("No VPN interface found with name \(vpnNetworkInterfaceName).")
            throw PlutoniumError.vpnInterfaceNotFound
        }

        log.debug("VPN interface found: \(vpnInterface)")
        self.vpnInterface = vpnInterface

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
                            log.info("FlowHandlingManager initialised in exclusion mode with \(self?.appIDs.count ?? 0) excluded apps, \(self?.ipSet.count ?? 0) excluded IPs and internet interface \(interface?.name ?? "undefined").")
                            hasInitialInterface = true
                        } else {
                            log.error("No internet interface found before VPN with interface name \(vpnNetworkInterfaceName).")
                            self?.onVpnUnavailable()
                            return
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

            self.networkInterface = vpnInterface
            log
                .info(
                    "FlowHandlingManager initialised in inclusion mode with \(appIDs.count) included apps, \(ipSet.count) included IPs and VPN interface \(vpnInterface.name)."
                )
        }

        // Start monitoring VPN interface
        startVPNInterfaceMonitoring(name: vpnNetworkInterfaceName)
    }

    private func startVPNInterfaceMonitoring(name vpnInterfaceName: String) {
        vpnNetworkInterfaceMonitorTask?.cancel()

        vpnNetworkInterfaceMonitorTask = Task { [weak self] in
            guard let self else { return }

            let vpnInterfaceStream = await NWInterface.monitorInterface(name: vpnInterfaceName)

            // Monitor for interface disappearance
            for await vpnInterface in vpnInterfaceStream {
                if vpnInterface == nil {
                    // Interface disappeared - start timeout
                    log.warning("VPN interface \(vpnInterfaceName) is no longer available, starting \(Self.vpnUnavailableTimeout) seconds timeout...")
                    await startVpnUnavailableTimeout()
                } else {
                    // Interface came back - cancel timeout
                    log.info("VPN interface \(vpnInterfaceName) is back, cancelling timeout")
                    await cancelVpnUnavailableTimeout()
                }
            }
        }
    }

    private func startVpnUnavailableTimeout() {
        guard vpnUnavailableTimeoutTask?.isCancelled != false else {
            log.debug("VPN unavailable timeout already active, not restarting")
            return
        }

        vpnUnavailableTimeoutTask = Task { [weak self] in
            do {
                try await Task.sleep(for: Self.vpnUnavailableTimeout)
                guard !Task.isCancelled else { return }

                // Timeout completed - interface still unavailable
                log.warning("VPN interface timeout expired, calling onVpnUnavailable")
                self?.onVpnUnavailable()
            } catch {
                log.error("VPN interface timeout task error: \(error)")
            }
        }
    }

    private func cancelVpnUnavailableTimeout() {
        vpnUnavailableTimeoutTask?.cancel()
        vpnUnavailableTimeoutTask = nil
    }

    private func add(_ handler: TCPFlowHandler) {
        activeTCPHandlers.insert(handler)

        // Start with cleanup callback
        Task {
            await handler.start { [weak self] in
                guard let self else { return }
                await remove(handler)
            }
        }
    }

    private func add(_ handler: UDPFlowHandler) {
        activeUDPHandlers.insert(handler)

        // Start with cleanup callback
        Task {
            await handler.start { [weak self] in
                guard let self else { return }
                await remove(handler)
            }
        }
    }

    // MARK: - Removal helpers

    private func remove(_ handler: TCPFlowHandler) {
        activeTCPHandlers.remove(handler)
    }

    private func remove(_ handler: UDPFlowHandler) {
        activeUDPHandlers.remove(handler)
    }

    private func cleanup() async {
        for handler in activeTCPHandlers {
            await handler.stop()
        }
        activeTCPHandlers.removeAll()

        for handler in activeUDPHandlers {
            await handler.stop()
        }
        activeUDPHandlers.removeAll()

        // Cancel network interface monitoring
        networkInterfaceMonitorTask?.cancel()
        networkInterfaceMonitorTask = nil

        // Cancel VPN monitoring as well
        vpnNetworkInterfaceMonitorTask?.cancel()
        vpnNetworkInterfaceMonitorTask = nil

        // Cancel VPN unavailable timeout
        vpnUnavailableTimeoutTask?.cancel()
        vpnUnavailableTimeoutTask = nil
    }

    private func updateNetworkInterface(_ interface: NWInterface?) {
        guard let interface else {
            log.warning("Internet interface is nil, ignoring update.")
            return
        }

        networkInterface = interface
        log.info("Internet interface set to \(interface)")
    }

    nonisolated func actionForFlow(_ flow: NEAppProxyFlow) -> RouteAction {
        guard let interface = networkInterface else {
            return .dontHandle
        }
        if let tcpFlow = flow as? NEAppProxyTCPFlow {
            guard appIDExists(tcpFlow.sourceAppIdentifier) || endpointIPExists(
                tcpFlow.remoteEndpoint
            ) else {
                return .dontHandle
            }
            guard let handler = TCPFlowHandler(
                tcpFlow: tcpFlow,
                targetInterface: interface
            ) else { return .dontHandle }
            return .forward(handler: handler)
        } else if let udpFlow = flow as? NEAppProxyUDPFlow {
            let endpointForwardingMode = appIDExists(udpFlow.sourceAppIdentifier) ? EndpointForwardingMode.all : .only(ips: ipSet)
            let handler = UDPFlowHandler(
                udpFlow: udpFlow,
                targetInterface: interface,
                vpnInterface: vpnInterface,
                endpointForwardingMode: endpointForwardingMode
            )
            return .forward(handler: handler)
        }
        return .dontHandle
    }

    // MARK: - Public registration helpers

    /// Track flow handlers.
    nonisolated func register(_ handler: FlowHandler) {
        if let tcpFlowHandler = handler as? TCPFlowHandler {
            Task { await add(tcpFlowHandler) }
        } else if let udpFlowHandler = handler as? UDPFlowHandler {
            Task { await add(udpFlowHandler) }
        }
    }

    nonisolated func cleanupAllHandlers() {
        Task {
            await cleanup()
        }
    }

    // MARK: Helper

    enum RouteAction {
        case dontHandle
        case forward(handler: FlowHandler)
    }

    private nonisolated func appIDExists(_ appID: String?) -> Bool {
        guard let appID else { return false }
        return appIDs.contains(appID) || pluginIDs.contains(appID)
    }

    private nonisolated func endpointIPExists(_ endpoint: NWEndpoint?) -> Bool {
        guard let endpoint, let ipString = endpoint.ipv4String else { return false }
        return ipSet.contains(ipString)
    }
}

extension NEAppProxyFlow {
    var sourceAppIdentifier: String? {
        metaData.sourceAppSigningIdentifier
    }
}
