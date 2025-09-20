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
    let id = UUID()

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

        self.connection = AsyncConnection(to: remoteEndpoint, using: parameters)

        logDebug("TCP flow handler initialized for remote endpoint \(remoteEndpoint) on interface \(targetInterface)")
    }

    // MARK: ‑ Public

    func start(onClose: @escaping @Sendable () async -> Void) async {
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

    func stop() async {
        guard !isCancelled else { return }
        isCancelled = true

        tcpFlow.closeReadWithError(nil)
        tcpFlow.closeWriteWithError(nil)

        connection.cancel()

        // Cancel the connection lifecycle task
        connectionLifecycleTask?.cancel()
        connectionLifecycleTask = nil

        await onClose?()
        logDebug("TCP tunnel connection closed")
    }

    // MARK: ‑ Connection state handling

    private func handleStateUpdate(_ state: NWConnection.State) async {
        switch state {
        case .setup:
            logDebug("TCP connection setup")
        case .preparing:
            logDebug("TCP connection preparing")
        case let .waiting(error):
            logDebug("TCP connection waiting: \(error.localizedDescription)")
        case .ready:
            logDebug("TCP flow handler connection ready")
            await startDataForwarding()
        case let .failed(error):
            logDebug("TCP flow handler connection failed: \(error.localizedDescription)")
            await stop()
        case .cancelled:
            logDebug("TCP connection cancelled")
            await stop()
        @unknown default:
            logDebug("TCP connection entered an unknown state")
        }
    }

    // MARK: ‑ Data forwarding

    private func startDataForwarding() async {
        await withCheckedContinuation { continuation in
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
            await stop()
            return
        }

        logDebug("TCP flow opened successfully, starting bidirectional forwarding")

        async let flowToConnection: Void = forwardFromFlowToConnection()
        async let connectionToFlow: Void = forwardFromConnectionToFlow()

        _ = await (flowToConnection, connectionToFlow)
    }

    // MARK: Forward app flow → target network

    private func forwardFromFlowToConnection() async {
        while !isCancelled {
            // Read data from the flow
            let (data, error) = await withCheckedContinuation { continuation in
                tcpFlow.readData { data, error in
                    continuation.resume(returning: (data, error))
                }
            }

            // Handle the read result
            let shouldContinue = await handleFlowRead(data: data, error: error)
            if !shouldContinue {
                break
            }
        }
    }

    private func handleFlowRead(data: Data?, error: Error?) async -> Bool {
        if let error {
            logError("Error reading from TCP flow: \(error.localizedDescription)")
            await stop()
            return false
        }

        guard let data, !data.isEmpty else {
            logInfo("TCP flow closed by client")
            await stop()
            return false
        }

        // Send data and wait for completion
        let sendError = await withCheckedContinuation { continuation in
            connection.send(content: data) { sendError in
                continuation.resume(returning: sendError)
            }
        }

        return await handleSendResult(sendError)
    }

    private func handleSendResult(_ error: NWError?) async -> Bool {
        if let error {
            logError("Error sending to tunnel: \(error.localizedDescription)")
            await stop()
            return false
        }
        return true // Continue the loop
    }

    // MARK: Forward network response → app

    private func forwardFromConnectionToFlow() async {
        while !isCancelled {
            // Receive data from the connection
            let (data, isDone, error) = await withCheckedContinuation { continuation in
                connection.receive(
                    minimumIncompleteLength: 1,
                    maximumLength: Self.maxBufferSize
                ) { data, _, isDone, error in
                    continuation.resume(returning: (data, isDone, error))
                }
            }

            // Handle the received data
            let shouldContinue = await handleConnectionReceive(
                data: data,
                isDone: isDone,
                error: error
            )
            if !shouldContinue {
                break
            }
        }
    }

    private func handleConnectionReceive(
        data: Data?,
        isDone: Bool,
        error: NWError?
    ) async -> Bool {
        if let error {
            logError("Error receiving from tunnel: \(error.localizedDescription)")
            await stop()
            return false
        }

        guard let data, !data.isEmpty else {
            if isDone {
                await stop()
                return false
            }
            return true
        }

        // Write data to flow and wait for completion
        let writeError = await withCheckedContinuation { continuation in
            tcpFlow.write(data) { writeError in
                continuation.resume(returning: writeError)
            }
        }

        return await handleFlowWriteResult(writeError, isDone: isDone)
    }

    private func handleFlowWriteResult(_ error: Error?, isDone: Bool) async -> Bool {
        if let error {
            logError("Error writing to TCP flow: \(error.localizedDescription)")
            await stop()
            return false
        }

        if isDone {
            await stop()
            return false
        }

        return true
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
