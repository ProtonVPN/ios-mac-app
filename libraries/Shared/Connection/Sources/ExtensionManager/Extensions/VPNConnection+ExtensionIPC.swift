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

import Foundation
import NetworkExtension
import Dependencies
import protocol ExtensionIPC.ProviderRequest
import enum ExtensionIPC.ProviderMessageError
import ConnectionFoundations

extension VPNSession {
    private var defaultMaxRetries: Int { 5 }

    public func send<R: ProviderRequest>(
        _ message: R,
        completion: ((Result<R.Response, ProviderMessageError>) -> Void)?
    ) {
        send(message, maxRetries: defaultMaxRetries, completion: completion)
    }

    private func send<R: ProviderRequest>(
        _ message: R,
        maxRetries: Int,
        completion: ((Result<R.Response, ProviderMessageError>) -> Void)?
    ) {
        // TODO: async implementation, retry failed messages sensibly
        try! sendProviderMessage(message.asData) { [weak self] response in
            guard let data = response else {
                // From documentation: "If this method can’t start sending the message it throws an error. If an
                // error occurs while sending the message or returning the result, `nil` should be sent to the
                // response handler as notification." If we encounter an xpc error, try sleeping for a second and
                // then trying again - the extension could still be launching, or we could be coming out of sleep.
                // If we retry enough times and still get nowhere, return an error.

                guard maxRetries > 0 else {
                    completion?(.failure(.noDataReceived))
                    return
                }

                log.debug(
                    "NETunnelProviderSessionWrapper encountered xpc error, retrying in 1 second",
                    category: .ipc,
                    metadata: ["retries": "\(maxRetries)"]
                )
                DispatchQueue.main.asyncAfter(deadline: .now() + 1) {
                    self?.send(message, maxRetries: maxRetries - 1, completion: completion)
                }
                return
            }

            do {
                let response = try R.Response.decode(data: data)
                log.debug(
                    "NETunnelProviderSessionWrapper received provider message response",
                    category: .ipc,
                    metadata: ["reponse": "\(String(describing: response))"]
                )
                completion?(.success(response))
            } catch {
                completion?(.failure(.decodingError))
            }
        }
    }
}

public struct TunnelMessageSenderImplementation: TunnelMessageSender {
    @Dependency(\.tunnelManager) var tunnelManager

    public func send<R: ProviderRequest>(_ message: R) async throws -> R.Response {
        try await tunnelManager.session.send(message)
    }
}

extension TunnelMessageSenderKey: DependencyKey {
    public static let liveValue: TunnelMessageSender = TunnelMessageSenderImplementation()
}
