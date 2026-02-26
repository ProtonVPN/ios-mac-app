//
//  Created on 30/09/2025 by Adam Viaud.
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

import Logging
@preconcurrency import NetworkExtension
import OSLog

@preconcurrency import VPNAppCore

open class PlutoniumTransparentProxyProvider: NETransparentProxyProvider {
    private var flowManager: FlowHandlingManager?

    override open func startProxy(options _: [String: Any]? = nil, completionHandler: @escaping ((any Error)?) -> Void) {
        guard
            let tunnelProto = protocolConfiguration as? NETunnelProviderProtocol,
            let rawConfig = tunnelProto.providerConfiguration,
            let configuration: PlutoniumProviderConfiguration = {
                do {
                    return try PlutoniumProviderConfiguration(from: rawConfig)
                } catch {
                    Logger.provider.error("Failed to parse provider configuration: \(error)")
                    return nil
                }
            }()
        else {
            completionHandler(PlutoniumError.noConfigurationFound)
            return
        }

        flowManager = FlowHandlingManager(plutoniumConfiguration: configuration)
        flowManager?.startPathMonitoring()

        Logger.provider.info("Starting proxy provider.")

        nonisolated(unsafe) let unsafeSelf = self
        nonisolated(unsafe) let handler = completionHandler
        let settings = SettingsGenerator.settings(capturingTraffic: true)

        Task { @MainActor in
            do {
                try await unsafeSelf.setTunnelNetworkSettings(settings)
                handler(nil)
            } catch {
                handler(error)
            }
        }
    }

    override open func stopProxy(with reason: NEProviderStopReason) async {
        Logger.provider.info("Stopping proxy provider with reason: \(String(describing: reason))")

        flowManager?.stopAll()
    }

    override open func sleep() async {
        Logger.provider.info("Proxy provider put to sleep...")

        flowManager?.stopAll()
        flowManager?.stopPathMonitoring()

        await super.sleep()
    }

    override open func wake() {
        flowManager?.startPathMonitoring()

        super.wake()

        Logger.provider.info("Proxy provider waking up...")
    }

    override open func handleNewFlow(_ flow: NEAppProxyFlow) -> Bool {
        guard let flowManager else {
            return false
        }
        switch flowManager.routeActionForFlow(flow) {
        case .dontHandle:
            return false
        case let .forward(handler):
            flowManager.registerAndStart(flow: handler)
            return true
        }
    }
}
