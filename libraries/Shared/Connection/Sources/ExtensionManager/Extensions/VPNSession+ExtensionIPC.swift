//
//  Created on 04/06/2024.
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

import CoreConnection
import Dependencies
import enum ExtensionIPC.ProviderMessageError
import protocol ExtensionIPC.ProviderRequest
import enum ExtensionIPC.WireguardProviderRequest
import Foundation
import NetworkExtension

extension VPNSession {
    func send(_ message: WireguardProviderRequest, withRetries retries: Int, retryInterval: Duration) async throws -> Data {
        @Dependency(\.continuousClock) var clock

        let messageData = message.asData
        // From documentation: "If this method can’t start sending the message it throws an error. If an error occurs
        // while sending the message or returning the result, `nil` should be sent to the response handler as
        // notification." If we encounter an xpc error, try sleeping for a second and then trying again - the extension
        // could still be launching, or we could be coming out of sleep. If we retry enough times and still get
        // nowhere, return an error.
        for attempt in 1 ... retries {
            log.debug("Sending provider message", category: .ipc, metadata: ["message": "\(message)", "attempt": "\(attempt)"])
            let data: Data? = try await _sendProviderMessage(messageData)
            try Task.checkCancellation()

            if let data {
                return data
            }

            if attempt == retries {
                // Prevent sleeping if we're not going to retry afterwards
                break
            }

            log.debug("No data received, retrying after: \(retryInterval)", category: .ipc, metadata: ["message": "\(message)"])
            try await clock.sleep(for: retryInterval)

            try Task.checkCancellation()
        }

        log.error("Retries exhausted, no data received", category: .ipc, metadata: ["message": "\(message)"])
        throw ProviderMessageError.noDataReceived
    }
}

@available(iOS 16, *)
extension TunnelMessageSender: DependencyKey {
    public static let liveValue: TunnelMessageSender = {
        @Dependency(\.tunnelManager) var tunnelManager
        return TunnelMessageSender(
            send: { message in
                try await tunnelManager.session.send(message)
            }
        )
    }()
}
