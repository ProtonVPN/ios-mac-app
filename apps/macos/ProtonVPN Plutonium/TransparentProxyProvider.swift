//
//  Created on 10/04/2025 by Shahin Katebi.
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
import Network
import os

class TransparentProxyProvider: NETransparentProxyProvider {

    private static let targetAppIdentifier = "com.openai.chat"
    private let log = OSLog(subsystem: "ch.protonmail.vpn", category: "TransparentProxy")

    override init() {
        super.init()
        os_log("TransparentProxyProvider initialized", log: log, type: .debug)
    }

    override func startProxy(options: [String: Any]?, completionHandler: @escaping (Error?) -> Void) {
        os_log("Starting proxy provider", log: log, type: .info)

        let settings = createNetworkSettings()
        setTunnelNetworkSettings(settings) { error in
            if let error = error {
                os_log(
                    "Failed to set tunnel network settings: %{public}@",
                    log: self.log,
                    type: .error,
                    error.localizedDescription
                )
            } else {
                os_log("Successfully set tunnel network settings", log: self.log, type: .info)
            }
            completionHandler(error)
        }
    }

    override func stopProxy(with reason: NEProviderStopReason, completionHandler: @escaping () -> Void) {
        os_log("Stopping proxy provider with reason: %{public}d", log: log, type: .info, reason.rawValue)
        completionHandler()
    }

    override func handleNewFlow(_ flow: NEAppProxyFlow) -> Bool {
        let sourceAppIdentifier = flow.metaData.sourceAppSigningIdentifier

        if let tcpFlow = flow as? NEAppProxyTCPFlow {
            os_log("New TCP flow from: %{public}@", log: log, type: .debug, sourceAppIdentifier)

            if sourceAppIdentifier == Self.targetAppIdentifier {
                os_log("Blocking TCP connection from %{public}@", log: log, type: .debug, sourceAppIdentifier)
                handleBlockedTCPFlow(tcpFlow)
                return true
            }

            os_log("Ignoring non-blocked TCP flow", log: log, type: .debug)
            return false

        } else if let udpFlow = flow as? NEAppProxyUDPFlow {
            os_log("New UDP flow from: %{public}@", log: log, type: .debug, sourceAppIdentifier)

            if sourceAppIdentifier == Self.targetAppIdentifier {
                os_log("Blocking UDP connection from %{public}@", log: log, type: .debug, sourceAppIdentifier)
                handleBlockedUDPFlow(udpFlow)
                return true
            }

            os_log("Ignoring non-blocked UDP flow", log: log, type: .debug)
            return false
        }

        os_log("Unknown flow type (neither TCP nor UDP) -> ignoring", log: log, type: .debug)
        return false
    }

    private func createNetworkSettings() -> NETransparentProxyNetworkSettings {
        let settings = NETransparentProxyNetworkSettings(tunnelRemoteAddress: "127.0.0.1")

        let allTCPRule = NENetworkRule(
            remoteNetwork: nil,
            remotePrefix: 0,
            localNetwork: nil,
            localPrefix: 0,
            protocol: .TCP,
            direction: .outbound
        )

        let allUDPRule = NENetworkRule(
            remoteNetwork: nil,
            remotePrefix: 0,
            localNetwork: nil,
            localPrefix: 0,
            protocol: .UDP,
            direction: .outbound
        )

        settings.includedNetworkRules = [allTCPRule, allUDPRule]
        return settings
    }

    private func handleBlockedTCPFlow(_ flow: NEAppProxyTCPFlow) {
        flow.open(withLocalEndpoint: nil) { error in
            if error == nil {
                os_log("TCP flow blocked (opened but no data forwarded)", log: self.log, type: .info)
                let err = NSError(domain: NSPOSIXErrorDomain, code: Int(ECONNREFUSED), userInfo: nil)
                flow.closeReadWithError(err)
                flow.closeWriteWithError(err)
            } else {
                os_log("Error opening TCP flow for blocking: %{public}@", log: self.log, type: .error, "\(error!)")
            }
        }
    }

    private func handleBlockedUDPFlow(_ flow: NEAppProxyUDPFlow) {
        flow.open(withLocalEndpoint: nil) { error in
            if error == nil {
                os_log("UDP flow blocked (opened but no data forwarded)", log: self.log, type: .info)
                let err = NSError(domain: NSPOSIXErrorDomain, code: Int(ECONNREFUSED), userInfo: nil)
                flow.closeReadWithError(err)
                flow.closeWriteWithError(err)
            } else {
                os_log("Error opening UDP flow for blocking: %{public}@", log: self.log, type: .error, "\(error!)")
            }
        }
    }
}
