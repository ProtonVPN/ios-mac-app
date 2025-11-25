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

import NetworkExtension

open class ProTUNPacketTunnelProvider: NEPacketTunnelProvider {
    #if swift(>=6.2)
        override open func startTunnel(options _: [String: NSObject]? = nil, completionHandler: @escaping ((any Error)?) -> Void) {
            completionHandler(nil)
        }
    #else
        override open func startTunnel(options _: [String: NSObject]? = nil) async throws {
            // Add code here to start the process of connecting the tunnel.
        }
    #endif

    override open func stopTunnel(with _: NEProviderStopReason) async {
        // Add code here to start the process of stopping the tunnel.
    }

    override open func handleAppMessage(_: Data) async -> Data? {
        // Add code here to handle the message.
        nil
    }

    override open func sleep() async {
        // Add code here to get ready to sleep.
    }

    override open func wake() {
        // Add code here to wake up.
    }
}
