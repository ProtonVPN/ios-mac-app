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
import Network
import NetworkExtension
import os
import PMLogger

@preconcurrency import VPNAppCore

open class PlutoniumTransparentProxyProvider: NETransparentProxyProvider {
    override public init() {
        super.init()
        setupLogs()
    }

    @SharedReader(.plutoniumFeature) private var feature: PlutoniumFeatureToggle
    private var flowHandlingManager: FlowHandlingManager?

    override open func startProxy(options _: [String: Any]?, completionHandler: @escaping (Error?) -> Void) {
        log.info("Starting proxy provider.")
        guard case .enabled = feature else {
            log.warning("Plutonium feature is not enabled. Should not have started proxy provider.")
            completionHandler(PlutoniumError.featureDisabled)
            stopProxy(with: .none, completionHandler: {})
            return
        }

        let settings = createNetworkSettings()
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
                            vpnNetworkInterfaceName: vpnNetworkInterfaceName
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

    override open func stopProxy(with reason: NEProviderStopReason, completionHandler: @escaping () -> Void) {
        log.debug("Stopping proxy provider with reason: \(reason)")

        flowHandlingManager?.cleanupAllHandlers()
        flowHandlingManager = nil

        completionHandler()
    }

    override open func handleNewFlow(_ flow: NEAppProxyFlow) -> Bool {
        guard let flowHandlingManager else {
            log.error("Flow Handling helper is not available.")
            return false
        }

        switch flowHandlingManager.actionForFlow(flow) {
        case .dontHandle:
            return false
        case let .forward(handler: handler):
            flowHandlingManager.register(handler)
            return true
        }
    }

    private func createNetworkSettings() -> NETransparentProxyNetworkSettings {
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

        settings.includedNetworkRules = [allTCPRule, allUDPRule]
        return settings
    }

    private func setupLogs() {
        // TODO: VPNAPPL-2789: Define dependency container for the logFileManager.
        let logFile = PMLogger.LogFileManagerImplementation().getFileUrl(named: "Proton-Plutonium.log")

        let fileLogHandler = FileLogHandler(logFile)
        let osLogHandler = OSLogHandler(formatter: OSLogFormatter())
        let multiplexLogHandler = MultiplexLogHandler([osLogHandler, fileLogHandler])

        LoggingSystem.bootstrap { _ in multiplexLogHandler }
    }

    // MARK: - Helpers

    private static func fetchVpnInterfaceName() async throws -> String {
        let xpcClient = WireguardXPCClient()
        return try await xpcClient.getInterfaceName()
    }

    /// A sendable wrapper for completion handlers to safely pass across isolation boundaries
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
}
