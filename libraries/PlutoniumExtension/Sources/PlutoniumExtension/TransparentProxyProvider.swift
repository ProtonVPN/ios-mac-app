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

import Foundation
import Network
@preconcurrency import NetworkExtension
import os
import Logging
import PMLogger
import ComposableArchitecture

@preconcurrency import VPNAppCore

open class PlutoniumTransparentProxyProvider: NETransparentProxyProvider, @unchecked Sendable
{

    private var activeTCPHandlers: Set<TCPFlowHandler> = []
    private var networkInterface: NWInterface?

    public override init() {
        super.init()
        setupLogs()
    }

    @SharedReader(.plutoniumFeature) private var feature: PlutoniumFeatureToggle
    private lazy var inclusionHelper: PlutoniumInclusionHelper? = {
        do {
            return try PlutoniumInclusionHelper()
        } catch {
            log.error("Failed to initialize PlutoniumInclusionHelper: \(error)")
            return nil
        }
    }()

    open override func startProxy(options: [String: Any]?, completionHandler: @escaping (Error?) -> Void) {
        log.info("Starting proxy provider.")
        guard case .enabled = feature else {
            log.warning("Plutonium feature is not enabled. Should not have started proxy provider.")
            completionHandler(PlutoniumError.featureDisabled)
            self.stopProxy(with: .none, completionHandler: {})
            return
        }

        let sendableCompletion = SendableCompletion(completion: completionHandler)
        let settings = createNetworkSettings()
        setTunnelNetworkSettings(settings) { error in
            if let error = error {
                log.error("Failed to set tunnel network settings: \(error)")
            } else {
                log.info("Successfully set tunnel network settings.")
            }
            Task { @MainActor [weak self] in
                guard let self = self else { return }
    //            self.networkInterface = await findWireGuardInterface(expectedIP: "10.2.0.2")
                self.networkInterface = await NWInterface.findInternetInterface()
                if let networkInterface {
                    log.info("Found network interface: \(networkInterface.name) (\(networkInterface.type))")
                    sendableCompletion(nil)
                } else {
                    log.error("Network interface not found")
                    sendableCompletion(NEVPNError(.configurationInvalid))
                }
            }
        }

    }

    open override func stopProxy(with reason: NEProviderStopReason, completionHandler: @escaping () -> Void) {
        log.debug("Stopping proxy provider with reason: \(reason)")
        completionHandler()
    }

    open override func handleNewFlow(_ flow: NEAppProxyFlow) -> Bool {
        let sourceAppIdentifier = flow.metaData.sourceAppSigningIdentifier

        guard let inclusionHelper else {
            log.error("Inclusion helper is not available.")
            return false
        }

        if let tcpFlow = flow as? NEAppProxyTCPFlow {
//            log.debug("New TCP flow from: \(sourceAppIdentifier)")

            guard let networkInterface else {
                log.error("No internet interface available")
                return false
            }

            if !inclusionHelper.appIncluded(withIdentifier: sourceAppIdentifier) {
                log.debug("Routing excluded TCP connection from \(sourceAppIdentifier) through \(networkInterface.name) network interface")
                return handleTCPFlow(tcpFlow, through: networkInterface)
            }

//            log.debug("Allowing included TCP flow to go through VPN.")
            return false

        } else if let udpFlow = flow as? NEAppProxyUDPFlow {
//            log.debug("New UDP flow from: \(sourceAppIdentifier)")

            guard let networkInterface else {
                log.error("No internet interface available")
                return false
            }

            if !inclusionHelper.appIncluded(withIdentifier: sourceAppIdentifier) {
                log.debug("Routing excluded UDP connection from \(sourceAppIdentifier) through \(networkInterface.name) network interface")
                return handleUDPFlow(udpFlow, through: networkInterface)
            }

//            log.debug("Allowing included UDP flow to go through VPN.")
            return false
        }

        log.debug("Unknown flow type (neither TCP nor UDP) -> ignoring")
        return false
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

    private func blockFlow(_ flow: NEAppProxyFlow) {
        let err = NSError(domain: NSPOSIXErrorDomain, code: Int(ECONNREFUSED), userInfo: nil)
        flow.closeReadWithError(err)
        flow.closeWriteWithError(err)
    }

    private func setupLogs() {
        // TODO: VPNAPPL-2789: Define dependency container for the logFileManager.
        let logFile = PMLogger.LogFileManagerImplementation().getFileUrl(named: "Proton-Plutonium.log")

        let fileLogHandler = FileLogHandler(logFile)
        let osLogHandler = OSLogHandler(formatter: OSLogFormatter())
        let multiplexLogHandler = MultiplexLogHandler([osLogHandler, fileLogHandler])

        LoggingSystem.bootstrap { _ in return multiplexLogHandler }
    }


    // MARK: - TCP Flow Handling

    private func handleTCPFlow(_ flow: NEAppProxyTCPFlow, through interface: NWInterface) -> Bool {

        guard let tcpFlowHandler = TCPFlowHandler(flow: flow, interface: interface) else {
            return false
        }

        activeTCPHandlers.insert(tcpFlowHandler)

        tcpFlowHandler.onClose = { [weak self] in
            self?.activeTCPHandlers.remove(tcpFlowHandler)
        }

        tcpFlowHandler.start()
        return true
    }

    // MARK: - UDP Flow Handling

    private func handleUDPFlow(_ flow: NEAppProxyUDPFlow, through interface: NWInterface) -> Bool {
        return false
    }


    // MARK: - Helpers
    private struct SendableCompletion: @unchecked Sendable {
        let completion: (Error?) -> Void

        func callAsFunction(_ error: Error?) {
            Task { @MainActor in
                  completion(error)
            }
        }
    }
}
