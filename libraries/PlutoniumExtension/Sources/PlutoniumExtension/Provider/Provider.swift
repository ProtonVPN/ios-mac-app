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

@preconcurrency import NetworkExtension
import OSLog
import Logging

@preconcurrency import VPNAppCore

open class PlutoniumTransparentProxyProvider: NETransparentProxyProvider {
    private var flowManager: FlowHandlingManager?

    override open func startProxy(options _: [String: Any]? = nil) async throws {
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
            throw PlutoniumError.noConfigurationFound
        }

        flowManager = FlowHandlingManager(plutoniumConfiguration: configuration)

        Logger.provider.info("Starting proxy provider.")

        let settings = SettingsGenerator.settings(capturingTraffic: true)

        try await setTunnelNetworkSettings(settings)
    }

    override open func stopProxy(with reason: NEProviderStopReason) async {
        Logger.provider.info("Stopping proxy provider with reason: \(String(describing: reason))")

        flowManager?.stopAll()
    }

    override open func sleep() async {
        Logger.provider.info("Proxy provider put to sleep...")

        flowManager?.stopAll()

        await super.sleep()
    }

    override open func wake() {
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
