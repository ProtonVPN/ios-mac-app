//
//  Created on 20/06/2025 by Shahin Katebi.
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
import Logging
import VPNShared

/// XPC client for communicating with the WireGuard extension
final class WireguardXPCClient {
    private let machServiceName: String

    private lazy var connection: NSXPCConnection = {
        let connection = NSXPCConnection(machServiceName: machServiceName)
        connection.remoteObjectInterface = NSXPCInterface(with: ProviderCommunication.self)

        connection.invalidationHandler = {
            log.debug("XPC connection invalidated")
        }

        connection.interruptionHandler = {
            log.debug("XPC connection interrupted")
        }

        connection.resume()
        return connection
    }()

    init() {
        let teamIdentifierPrefix = Bundle.main.infoDictionary!["TeamIdentifierPrefix"] as! String
        self.machServiceName = "\(teamIdentifierPrefix)group.ch.protonvpn.mac.WireGuard-Extension"
    }

    deinit {
        connection.invalidate()
    }

    /// Get the WireGuard interface name via XPC
    func getInterfaceName() async throws -> String {
        try await withCheckedThrowingContinuation { continuation in
            guard let service = connection.remoteObjectProxyWithErrorHandler({ error in
                log.error("XPC proxy error: \(error)")
                continuation.resume(throwing: PlutoniumError.xpcConnectionError)
            }) as? ProviderCommunication else {
                log.error("Failed to get XPC service proxy")
                continuation.resume(throwing: PlutoniumError.xpcConnectionError)
                return
            }

            service.getInterfaceName { interfaceName in
                if let interfaceName {
                    continuation.resume(returning: interfaceName)
                } else {
                    continuation.resume(throwing: PlutoniumError.vpnInterfaceNotFound)
                }
            }
        }
    }
}
