//
//  Created on 29/05/2024.
//
//  Copyright (c) 2024 Proton AG
//
//  ProtonVPN is free software: you can redistribute it and/or modify
//  it under the terms of the GNU General Public License as published by
//  the Free Software Foundation, either version 3 of the License, or
//  (at your option) any later version.
//
//  ProtonVPN is distributed in the hope that it will be useful,
//  but WITHOUT ANY WARRANTY; without even the implied warranty of
//  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
//  GNU General Public License for more details.
//
//  You should have received a copy of the GNU General Public License
//  along with ProtonVPN.  If not, see <https://www.gnu.org/licenses/>.

import Foundation

import class NetworkExtension.NETunnelProviderManager
import class NetworkExtension.NETunnelProviderProtocol
import class NetworkExtension.NETunnelProviderSession
import class NetworkExtension.NEVPNManager

extension NETunnelProviderSession: VPNSession {
    public func fetchLastDisconnectError() async -> Error? {
        // For some reason, the native async alternative returns `Void`
        // return try await fetchLastDisconnectError()
        await withCheckedContinuation { continuation in
            self.fetchLastDisconnectError(completionHandler: continuation.resume(returning:))
        }
    }
}

extension NETunnelProviderManager: TunnelProviderManager {
    public var vpnProtocolConfiguration: NETunnelProviderProtocol? {
        get {
            guard let configuration = connection.manager.protocolConfiguration else {
                return nil
            }

            guard let protocolConfiguration = configuration as? NETunnelProviderProtocol else {
                assertionFailure("Expected TunnelProvider configuration")
                return nil
            }

            return protocolConfiguration
        }
        set {
            connection.manager.protocolConfiguration = newValue
        }
    }
    
    public var session: VPNSession {
        guard let session = connection as? NETunnelProviderSession else {
            // If we cannot communicate with the extension, VPN functionality is crippled.
            // This can only happen if we seriously misconfigure the tunnel provider manager.
            // Let's make this obvious by instantly crashing here.
            fatalError()
        }

        return session
    }
}
