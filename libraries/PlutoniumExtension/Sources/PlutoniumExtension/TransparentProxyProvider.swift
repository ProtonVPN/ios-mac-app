//
//  Created on 11/04/2025 by Shahin Katebi.
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
import Logging
import NetworkExtension
import PMLogger
@preconcurrency import VPNAppCore

open class PlutoniumTransparentProxyProvider: NETransparentProxyProvider {
    private var flowHandlingManager: FlowHandlingManager?

    override open func startProxy(options _: [String: Any]?, completionHandler: @escaping (Error?) -> Void) {
        guard
            let tunnelProto = protocolConfiguration as? NETunnelProviderProtocol,
            let rawConfig = tunnelProto.providerConfiguration,
            let configuration: PlutoniumProviderConfiguration = {
                do {
                    return try PlutoniumProviderConfiguration(from: rawConfig)
                } catch {
                    log.error("Failed to parse provider configuration: \(error)")
                    return nil
                }
            }()
        else {
            completionHandler(PlutoniumError.noConfigurationFound)
            return
        }

        let settings = Self.createNetworkSettings(capturingTraffic: true)
        log.info("Starting proxy provider.")

        setTunnelNetworkSettings(settings) { [weak self] error in
            if let error {
                log.error("Failed to set tunnel network settings: \(error)")
                completionHandler(error)
            } else {
                log.info("Successfully set tunnel network settings.")
                guard let self else {
                    log.error("Cannot continue setting up the flow handling manager since self is nil.")
                    completionHandler(PlutoniumError.unexpectedError)
                    return
                }
                // Create a sendable wrapper for the completion handler
                let sendableCompletion = SendableCompletion(completionHandler, provider: self)
                // Create callback for when FlowHandlingManager stops
                let sendableVpnUnavailableCallback = SendableVpnUnavailableCallback(provider: self)

                Task { @Sendable in
                    // Try to get the WireGuard interface name via XPC request
                    let vpnNetworkInterfaceName: String
                    do {
                        vpnNetworkInterfaceName = try await Self.fetchVpnInterfaceName()
                    } catch {
                        log.error("Failed to fetch VPN interface name: \(error)")
                        sendableCompletion.call(error)
                        return
                    }

                    log.info("VPN interface name: \(vpnNetworkInterfaceName)")

                    do {
                        let manager = try await FlowHandlingManager(
                            vpnNetworkInterfaceName: vpnNetworkInterfaceName,
                            plutoniumConfiguration: configuration,
                            onVpnUnavailable: sendableVpnUnavailableCallback.call
                        )
                        sendableCompletion.call(nil, manager: manager)
                    } catch {
                        log.error("Failed to initialize flow handling manager: \(error)")
                        sendableCompletion.call(error)
                    }
                }
            }
        }
    }

    private var isStopping = false
    override open func stopProxy(with reason: NEProviderStopReason, completionHandler: @escaping () -> Void) {
        guard isStopping == false else {
            return
        }
        isStopping = true

        log.debug("Stopping proxy provider with reason: \(reason)")

        flowHandlingManager?.cleanupAllHandlers()
        flowHandlingManager = nil
        completionHandler()
    }

    override open func sleep() async {
        log.debug("Proxy provider put to sleep...")
    }

    override open func wake() {
        log.debug("Proxy provider waking up...")
    }

    override open func handleNewFlow(_ flow: NEAppProxyFlow) -> Bool {
        guard let flowHandlingManager else {
            log.error("Flow Handling helper is not available.")
            return false
        }

        switch flowHandlingManager.routeActionForFlow(flow) {
        case .dontHandle:
            return false
        case let .forward(handler: handler):
            flowHandlingManager.register(handler)
            return true
        }
    }

    private static func createNetworkSettings(capturingTraffic: Bool = true) -> NETransparentProxyNetworkSettings {
        let settings = NETransparentProxyNetworkSettings(tunnelRemoteAddress: "127.0.0.1")

        let allTCPRule = NENetworkRule(
            __remoteNetwork: nil,
            remotePrefix: 0,
            localNetwork: nil,
            localPrefix: 0,
            protocol: .TCP,
            direction: .outbound
        )

        let allUDPRule = NENetworkRule(
            __remoteNetwork: nil,
            remotePrefix: 0,
            localNetwork: nil,
            localPrefix: 0,
            protocol: .UDP,
            direction: .outbound
        )

        if capturingTraffic {
            settings.includedNetworkRules = [allTCPRule, allUDPRule]
            do {
                let rule = try NENetworkRule.dnsRule
                settings.excludedNetworkRules = [rule]
            } catch {
                settings.excludedNetworkRules = []
            }
        } else {
            settings.includedNetworkRules = []
            settings.excludedNetworkRules = [allTCPRule, allUDPRule]
        }

        return settings
    }

    // MARK: - Helpers

    private static func fetchVpnInterfaceName() async throws -> String {
        let xpcClient = WireguardXPCClient()
        return try await xpcClient.getInterfaceName()
    }

    /// Specific sendable completion for manager creation
    private struct SendableCompletion: Sendable {
        private nonisolated(unsafe) let completion: (Error?) -> Void
        private nonisolated(unsafe) weak var provider: PlutoniumTransparentProxyProvider?

        init(_ completion: @escaping (Error?) -> Void, provider: PlutoniumTransparentProxyProvider) {
            self.completion = completion
            self.provider = provider
        }

        func call(_ error: Error?, manager: FlowHandlingManager? = nil) {
            Task { @MainActor in
                if let manager {
                    provider?.flowHandlingManager = manager
                }
                completion(error)
            }
        }
    }

    /// Specific sendable callback for stopping the proxy
    private struct SendableVpnUnavailableCallback: Sendable {
        private nonisolated(unsafe) weak var provider: PlutoniumTransparentProxyProvider?

        init(provider: PlutoniumTransparentProxyProvider) {
            self.provider = provider
        }

        func call() {
            Task { @MainActor in
                let settings = PlutoniumTransparentProxyProvider.createNetworkSettings(capturingTraffic: false)
                provider?.setTunnelNetworkSettings(settings) { error in
                    if let error {
                        log.error("Failed to set tunnel network settings before stopping: \(error)")
                    }
                    provider?.stopProxy(with: .providerFailed) {}
                }
            }
        }
    }
}
