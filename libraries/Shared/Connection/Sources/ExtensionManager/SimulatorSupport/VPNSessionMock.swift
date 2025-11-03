//
//  Created on 31/05/2024.
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

#if targetEnvironment(simulator)
    import let CoreConnection.log
    import struct CoreConnection.LogicalServerInfo
    import Dependencies
    import ExtensionIPC
    import Foundation
    import IssueReporting
    import enum NetworkExtension.NEVPNStatus
    import VPNShared

    final class VPNSessionMock: VPNSession {
        var connectedDate: Date?
        var connectedServer: LogicalServerInfo = .init(logicalID: "", serverID: "")
        var status: NEVPNStatus {
            didSet {
                NotificationCenter.default.post(name: Notification.Name.NEVPNStatusDidChange, object: self)
            }
        }

        /// Action that will be executed as the tunnel starts connecting
        var onConnection: (() -> Void)?

        /// Time taken to enter the `.connecting` state. If `nil`, the transition should be performed manually
        var startupDuration: Duration? = .seconds(0)
        /// Time taken to enter the `.connected` state. If `nil`, the transition needs to be performed manually
        var connectionDuration: Duration? = .seconds(1)
        var connectionTask: Task<Void, Error>?
        /// Time taken to enter the `.disconnected` state. If `nil`, the transition needs to be performed manually
        var disconnectionDuration: Duration? = .seconds(1)
        var disconnectionTask: Task<Void, Error>?
        var lastDisconnectError: Error?
        var messageHandler: ((VPNSessionMock, WireguardProviderRequest) async throws(ProviderMessageError) -> WireguardProviderRequest.Response)?
        var internalMessageSender: (Data) async throws -> Data?

        init(
            status: NEVPNStatus,
            connectedDate: Date? = nil,
            lastDisconnectError: Error? = nil
        ) {
            log.info("VPNSessionMock init")
            self.status = status
            self.connectedDate = connectedDate
            self.lastDisconnectError = lastDisconnectError
            self.internalMessageSender = { _ in
                reportIssue("Unimplemented internal message sender")
                return nil
            }
        }

        func fetchLastDisconnectError() async throws -> Error? { lastDisconnectError }

        func startTunnel() throws {
            onConnection?()

            guard let startupDuration else { return }
            let shouldTransitionToConnectingImmediately = startupDuration == .zero
            if shouldTransitionToConnectingImmediately {
                status = .connecting
            }

            guard let connectionDuration else { return }
            connectionTask = Task {
                @Dependency(\.continuousClock) var clock
                if !shouldTransitionToConnectingImmediately {
                    try await clock.sleep(for: startupDuration)
                    if Task.isCancelled { return }
                    self.status = .connecting
                }

                try await clock.sleep(for: connectionDuration)
                if Task.isCancelled { return }

                @Dependency(\.date) var date
                connectedDate = date.now
                self.status = .connected
            }
        }

        func stopTunnel() {
            guard let disconnectionDuration else { return }
            connectionTask?.cancel()
            if status == .disconnected {
                return
            }
            status = .disconnecting
            disconnectionTask = Task {
                @Dependency(\.continuousClock) var clock
                try await clock.sleep(for: disconnectionDuration)
                status = .disconnected
            }
        }

        // MARK: ProviderMessageSender conformance

        func send(_ message: WireguardProviderRequest) async throws(ProviderMessageError) -> WireguardProviderRequest.Response {
            guard let messageHandler else {
                reportIssue("Unimplemented message handler")
                return .error(message: "unimplemented message handler")
            }
            return try await messageHandler(self, message)
        }

        func _sendProviderMessage(_ messageData: Data) async throws -> Data? {
            try await internalMessageSender(messageData)
        }
    }

    enum MessageHandler {
        static let usingInternalSend: (VPNSessionMock, WireguardProviderRequest) async throws(ProviderMessageError) -> WireguardProviderRequest.Response = { session, message throws(ProviderMessageError) in
            let data = try await session.send(message, withRetries: 5, retryInterval: .seconds(1))
            do {
                return try WireguardProviderRequest.Response.decode(data: data)
            } catch {
                throw ProviderMessageError.decodingError
            }
        }

        static let full: (VPNSessionMock, WireguardProviderRequest) async throws(ProviderMessageError) -> WireguardProviderRequest.Response = { session, message in
            switch message {
            case .getCurrentLogicalAndServerId:
                return .ok(data: "\(session.connectedServer.logicalID);\(session.connectedServer.serverID)".data(using: .utf8)!)

            case let .refreshCertificate(features):
                @Dependency(\.date) var date
                @Dependency(\.vpnAuthenticationStorage) var keychain
                let tomorrow = date.now.addingTimeInterval(.days(1))
                let cert = VpnCertificate(certificate: "abcd", validUntil: tomorrow, refreshTime: tomorrow)
                let certWithFeatures = VpnCertificateWithFeatures(certificate: cert, features: features)
                keychain.store(certWithFeatures)

                return .ok(data: nil)

            case .setApiSelector:
                return .ok(data: nil)

            default:
                reportIssue("Unimplemented message handler for \(message)")
                return .error(message: "")
            }
        }
    }
#endif
