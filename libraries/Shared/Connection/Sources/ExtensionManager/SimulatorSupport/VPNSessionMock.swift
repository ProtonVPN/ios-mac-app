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

#if DEBUG
    import let CoreConnection.log
    import Dependencies
    import Domain
    import ExtensionIPC
    import ExtensionSync
    import Foundation
    import IPCDefinitions
    import IssueReporting
    import enum NetworkExtension.NEVPNStatus
    import Sharing
    import VPNShared

    final class VPNSessionMock: VPNSession {
        var connectedDate: Date?
        var connectedServerID: String = ""
        var onStatusChange: ((NEVPNStatus) -> Void)?

        var status: NEVPNStatus {
            didSet {
                onStatusChange?(status)
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
        var messageHandler: ((VPNSessionMock, ProTUNMessage.Request) async throws(ProviderMessageError) -> ProTUNMessage.Response)?
        var internalMessageSender: (Data) async throws -> Data?

        /// Published to the in-process `.mockExtensionState` cell so `@SharedReader(.extensionState)` reflects the
        /// mock, the way the network extension publishes via `extensionIPCServer`. Backs `ExtensionIPCClient.inMemoryBacked`.
        @Shared(.mockExtensionState) private var publishedExtensionState

        /// The fixed peer reported once the mock reaches `.connected`.
        static let testPeer = CurrentPeer(
            peerID: "peer-id",
            transport: .udp,
            serverExitV4: "203.0.113.7",
            serverExitV6: "2001:db8::7",
            userISP: "Proton ISP",
            userIP: "198.51.100.42"
        )

        init(
            status: NEVPNStatus,
            connectedDate: Date? = nil,
            lastDisconnectError: Error? = nil
        ) {
            log.info("VPNSessionMock init, status: \(status)", category: .connection)
            self.status = status
            self.connectedDate = connectedDate
            self.lastDisconnectError = lastDisconnectError
            self.internalMessageSender = { _ in
                reportIssue("Unimplemented internal message sender")
                return nil
            }
        }

        func fetchLastDisconnectError() async throws -> Error? {
            lastDisconnectError
        }

        /// Fakes a `RawChannel` publisher from the extension.
        private func publish(_ state: ExtensionState) {
            $publishedExtensionState.withLock { $0 = state }
        }

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
                // Before transitioning `status`, make sure that the extension state reports the test peer.
                self.publish(.connected(Self.testPeer))
                self.status = .connected
            }
        }

        func stopTunnel() {
            guard let disconnectionDuration else { return }
            connectionTask?.cancel()
            if status == .disconnected || status == .invalid {
                return
            }
            status = .disconnecting
            disconnectionTask = Task {
                @Dependency(\.continuousClock) var clock
                try await clock.sleep(for: disconnectionDuration)
                self.publish(.disconnected(reason: .unset))
                status = .disconnected
            }
        }

        // MARK: ProviderMessageSender conformance

        func _sendProviderMessage(_ messageData: Data) async throws -> Data? {
            try await internalMessageSender(messageData)
        }

        func sendProTUNRequest(_ message: Domain.ProTUNMessage.Request) async throws -> Domain.ProTUNMessage.Response {
            guard let messageHandler else {
                reportIssue("Unimplemented message handler")
                throw ProviderMessageError.notSupported
            }
            return try await messageHandler(self, message)
        }
    }

    enum MessageHandler {
        static let full: (VPNSessionMock, ProTUNMessage.Request) async throws(ProviderMessageError) -> ProTUNMessage.Response = { _, message in
            .genericError("Unimplemented message handler for \(message)")
        }
    }
#endif
