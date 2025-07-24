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
import Network
import NetworkExtension
import VPNShared

/// Handles TCP flow copying between network interfaces.
/// One instance per `NEAppProxyTCPFlow`.
final actor TCPFlowHandler: FlowHandler {
    private let id = UUID()

    // MARK: ‑ Constants

    private static let maxBufferSize = 512 * 1024 // 512 KB

    // MARK: ‑ Stored properties

    private let connection: AsyncConnection
    private let tcpFlow: NEAppProxyTCPFlow
    private let connectionQueue: DispatchQueue
    private var isCancelled = false
    private var onClose: (@Sendable () async -> Void)?
    private var connectionLifecycleTask: Task<Void, Never>?

    // MARK: ‑ Init

    init?(tcpFlow: NEAppProxyTCPFlow, targetInterface: NWInterface) {
        self.tcpFlow = tcpFlow

        let parameters = NWParameters.tcp
        parameters.requiredInterface = targetInterface

        guard let remoteEndpoint = tcpFlow.remoteEndpoint else {
            log.error("Cannot get remote endpoint for TCP flow")
            return nil
        }

        self.connectionQueue = DispatchQueue(
            label: "ch.protonvpn.plutonium.tcp-\(UUID().uuidString)",
            qos: .userInitiated
        )

        log.debug("TCP flow handler initialized for remote endpoint \(remoteEndpoint) on interface \(targetInterface)")
        self.connection = AsyncConnection(to: remoteEndpoint, using: parameters)
    }

    // MARK: ‑ Public

    nonisolated func start(onClose: @escaping @Sendable () async -> Void) {
        Task { await startIsolated(onClose: onClose) }
    }

    nonisolated func stop() {
        Task { await stopIsolated() }
    }

    // MARK: ‑ Private isolated helpers

    private func startIsolated(onClose: @escaping @Sendable () async -> Void) async {
        self.onClose = onClose

        let states = connection.states
        connectionLifecycleTask = Task { [weak self] in
            guard let self else { return }
            for await state in states {
                await handleStateUpdate(state)
            }
        }

        connection.start(queue: connectionQueue)
    }

    private func stopIsolated() async {
        guard !isCancelled else { return }
        isCancelled = true

        tcpFlow.closeWriteWithError(nil)

        connection.cancel()

        // Cancel the connection lifecycle task
        connectionLifecycleTask?.cancel()
        connectionLifecycleTask = nil

        await onClose?()
        log.info("TCP tunnel connection closed")
    }

    // MARK: ‑ Connection state handling

    private func handleStateUpdate(_ state: NWConnection.State) async {
        switch state {
        case .setup:
            log.debug("TCP connection setup")
        case .preparing:
            log.debug("TCP connection preparing")
        case let .waiting(error):
            log.debug("TCP connection waiting: \(error.localizedDescription)")
        case .ready:
            log.debug("TCP flow handler connection ready")
            await startDataForwarding()
        case let .failed(error):
            log.error("TCP flow handler connection failed: \(error.localizedDescription)")
            await stopIsolated()
        case .cancelled:
            log.debug("TCP connection cancelled")
            await stopIsolated()
        @unknown default:
            log.debug("TCP connection entered an unknown state")
        }
    }

    // MARK: ‑ Data forwarding

    private func startDataForwarding() async {
        await withCheckedContinuation { (continuation: CheckedContinuation<Void, Never>) in
            tcpFlow.open(withLocalEndpoint: nil) { [weak self] error in
                continuation.resume()
                guard let self else { return }
                Task { await self.handleFlowOpened(error) }
            }
        }
    }

    private func handleFlowOpened(_ error: Error?) async {
        if let error {
            log.error("Failed to open TCP flow: \(error.localizedDescription)")
            await stopIsolated()
            return
        }

        log.debug("TCP flow opened successfully, starting bidirectional forwarding")
        Task {
            await forwardFromFlowToConnection()
        }
        Task {
            await forwardFromConnectionToFlow()
        }
    }

    // MARK: Forward app flow → target network

    private func forwardFromFlowToConnection() async {
        guard !isCancelled else { return }

        await withCheckedContinuation { (continuation: CheckedContinuation<Void, Never>) in
            tcpFlow.readData { [weak self] data, error in
                continuation.resume()
                guard let self else { return }
                Task { await self.handleFlowRead(data: data, error: error) }
            }
        }
    }

    private func handleFlowRead(data: Data?, error: Error?) async {
        if let error {
            log.error("Error reading from TCP flow: \(error.localizedDescription)")
            await stopIsolated()
            return
        }

        guard let data, !data.isEmpty else {
            log.info("TCP flow closed by client")
            await stopIsolated()
            return
        }

        connection.send(content: data) { [weak self] (sendError: NWError?) in
            guard let self else { return }
            Task { await self.handleSendResult(sendError) }
        }
    }

    private func handleSendResult(_ error: NWError?) async {
        if let error {
            log.error("Error sending to tunnel: \(error.localizedDescription)")
            await stopIsolated()
        } else {
            await forwardFromFlowToConnection()
        }
    }

    // MARK: Forward network response → app

    private func forwardFromConnectionToFlow() async {
        guard !isCancelled else { return }

        connection.receive(
            minimumIncompleteLength: 1,
            maximumLength: Self.maxBufferSize
        ) { [weak self] data, _, isDone, error in
            guard let self else { return }
            Task { await self.handleConnectionReceive(
                data: data,
                isDone: isDone,
                error: error
            ) }
        }
    }

    private func handleConnectionReceive(
        data: Data?,
        isDone: Bool,
        error: NWError?
    ) async {
        if let error {
            log.error("Error receiving from tunnel: \(error.localizedDescription)")
            await stopIsolated()
            return
        }

        guard let data, !data.isEmpty else {
            if isDone { await stopIsolated() }
            return
        }

        await withCheckedContinuation { (continuation: CheckedContinuation<Void, Never>) in
            tcpFlow.write(data) { [weak self] writeError in
                continuation.resume()
                guard let self else { return }
                Task { await self.handleFlowWriteResult(writeError, isDone: isDone) }
            }
        }
    }

    private func handleFlowWriteResult(_ error: Error?, isDone: Bool) async {
        if let error {
            log.error("Error writing to TCP flow: \(error.localizedDescription)")
            await stopIsolated()
            return
        }

        if isDone {
            await stopIsolated()
        } else {
            await forwardFromConnectionToFlow()
        }
    }
}

// MARK: ‑ Hashable & Equatable

extension TCPFlowHandler: Hashable {
    nonisolated static func == (lhs: TCPFlowHandler, rhs: TCPFlowHandler) -> Bool {
        lhs.id == rhs.id
    }

    nonisolated func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }
}
