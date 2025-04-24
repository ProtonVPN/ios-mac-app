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
import NetworkExtension
import os
import Logging
import PMLogger

open class PlutoniumTransparentProxyProvider: NETransparentProxyProvider {

    // Temporary: Test App to jail
    private static let targetAppIdentifier = "com.example.app"

    public override init() {
        super.init()
        setupLogs()
    }

    open override func startProxy(options: [String: Any]?, completionHandler: @escaping (Error?) -> Void) {
        log.info("Starting proxy provider.")

        let settings = createNetworkSettings()
        setTunnelNetworkSettings(settings) { error in
            if let error = error {
                log.error("Failed to set tunnel network settings: \(error)")
            } else {
                log.info("Successfully set tunnel network settings.")
            }
            completionHandler(error)
        }
    }

    open override func stopProxy(with reason: NEProviderStopReason, completionHandler: @escaping () -> Void) {
        log.debug("Stopping proxy provider with reason: \(reason)")
        completionHandler()
    }

    open override func handleNewFlow(_ flow: NEAppProxyFlow) -> Bool {
        let sourceAppIdentifier = flow.metaData.sourceAppSigningIdentifier

        if let tcpFlow = flow as? NEAppProxyTCPFlow {
            log.debug("New TCP flow from: \(sourceAppIdentifier)")

            if sourceAppIdentifier == Self.targetAppIdentifier {
                log.debug("Blocking TCP connection from \(sourceAppIdentifier)")
                blockFlow(tcpFlow)
                return true
            }

            log.debug("Ignoring non-blocked TCP flow.")
            return false

        } else if let udpFlow = flow as? NEAppProxyUDPFlow {
            log.debug("New UDP flow from: \(sourceAppIdentifier)")

            if sourceAppIdentifier == Self.targetAppIdentifier {
                log.debug("Blocking UDP connection from \(sourceAppIdentifier)")
                blockFlow(udpFlow)
                return true
            }

            log.debug("Ignoring non-blocked UDP flow.")
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
}
