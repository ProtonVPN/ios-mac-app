//
//  Created on 17/04/2025 by adam.
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

#if DEBUG && FALSE
private import Network
private import Dispatch

public enum HermesResolverTester {
    private static let queue = DispatchQueue(label: "ch.protonvpn.connection.hermesResolverTester")

    public static func hitTest(_ location: String) async -> Bool {
        guard let ipAddress = IPv4Address(location) else {
            return false
        }
        return await withCheckedContinuation { continuation in
            let endpointHost = NWEndpoint.Host.ipv4(ipAddress)
            let connection = NWConnection(to: .hostPort(host: endpointHost, port: .init(rawValue: 53)!), using: .udp)
            connection.stateUpdateHandler = { newState in
                // TODO: VPNAPPL-2802
                // This is actually not doing the desired effect yet... it seems that it always transition to ready no
                // matter if the endpoint host is valid or not.
                switch newState {
                case .ready:
                    continuation.resume(returning: true)
                case .failed(_), .cancelled:
                    continuation.resume(returning: false)
                default:
                    continuation.resume(returning: false)
                }
            }
            connection.start(queue: queue)
        }
    }
}
#endif
