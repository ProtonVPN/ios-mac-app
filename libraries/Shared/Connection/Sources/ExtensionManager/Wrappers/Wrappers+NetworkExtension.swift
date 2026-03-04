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

import Domain

import class NetworkExtension.NETunnelProviderManager
import class NetworkExtension.NETunnelProviderProtocol
import class NetworkExtension.NETunnelProviderSession
import class NetworkExtension.NEVPNConnection
import class NetworkExtension.NEVPNManager

import let CoreConnection.log
import enum ExtensionIPC.ProviderMessageError
import enum ExtensionIPC.WireguardProviderRequest

extension NEVPNManager: TunnelProviderManager {
    public var session: VPNSession {
        connection
    }
}

/// Technically, only the `NETunnelProviderSession` subclass provides the `sendProviderMessage` method.
/// For simplicity's sake, we only define a single set of interfaces (`TunnelProviderManager` and `VPNSession`,
/// and throw a `notSupported` error if the caller tries to send a message using a manager that does not support
/// IPC (e.g. with IKE connecions).
/// Once we fully deprecate IKE on MacOS, we can instead move the conformance from `NEVPNManager` and `NEVPNConnection`
/// back to `NETunnelProviderManager` and `NETunnelProviderSession`.
extension NEVPNConnection: VPNSession {
    
    static let maxRetries = 5
    static let retryInterval = Duration.seconds(1)

    public func send(
        _ message: WireguardProviderRequest
    ) async throws(ProviderMessageError) -> WireguardProviderRequest.Response {
        let data = try await send(message, withRetries: Self.maxRetries, retryInterval: Self.retryInterval)
        return try WireguardProviderRequest.Response.decode(data: data)
    }

    public func _sendProviderMessage(_ messageData: Data) async throws -> Data? {
        guard let session = self as? NETunnelProviderSession else {
            // IPC is only possible for Tunnel Provider extensions.
            // This is thrown when the caller attempts to send a message to the IKE extension.
            throw ProviderMessageError.notSupported
        }
        return try await withCheckedThrowingContinuation { continuation in
            do {
                // Here is the place where we make the call to the real NetworkExtension API
                try session.sendProviderMessage(messageData) { optionalData in
                    continuation.resume(returning: optionalData)
                }
            } catch {
                continuation.resume(throwing: error)
            }
        }
    }

    public func startTunnel() throws {
        let id = UUID()
        log.debug("Starting VPN tunnel", category: .connection, metadata: ["activationAttemptId": "\(id)"])
        try startVPNTunnel(options: ["activationAttemptId": id.uuidString as NSString])
    }

    public func stopTunnel() {
        stopVPNTunnel()
    }

    public func fetchLastDisconnectError() async -> Error? {
        // For some reason, the native async alternative returns `Void`
        // return try await fetchLastDisconnectError()
        await withCheckedContinuation { [weak self] continuation in
            self?.fetchLastDisconnectError(completionHandler: { error in
                continuation.resume(returning: error)
            })
        }
    }
}
