//
//  Created on 23/06/2025 by Shahin Katebi.
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

/// Handles UDP flow copying between network interfaces.
/// One instance per `NEAppProxyUDPFlow`.
/// There will be an individual connection with its own queue per endpoint in the flow, which will be reused throughout the handling of the UDP flow.
final actor UDPFlowHandler {
    let id = UUID()

    // MARK: - Stored properties

    private let udpFlow: NEAppProxyUDPFlow
    private let targetInterface: NWInterface
    private var connectionLifecycleTasks: [NWEndpoint: Task<Void, Never>] = [:]
    private var sendChannels: [NWEndpoint: AsyncStream<Data>.Continuation] = [:]

    private var didCleanup = false
    private var onClose: (@Sendable () async -> Void)?

    private var handlerTask: Task<Void, Never>?

    // MARK: - Init

    init(udpFlow: NEAppProxyUDPFlow, targetInterface: NWInterface) {
        self.udpFlow = udpFlow
        self.targetInterface = targetInterface
        log.debug("UDP flow handler initialized for interface \(targetInterface.name)")
    }

    // MARK: - Public control

    nonisolated func start(onClose: @escaping @Sendable () async -> Void) {
        Task { await self.startIsolated(onClose: onClose) }
    }

    nonisolated func stop() {
        Task { await self.stopIsolated() }
    }

    private func startIsolated(onClose: @escaping @Sendable () async -> Void) async {
        guard handlerTask == nil else { return }

        self.onClose = onClose
        handlerTask = Task(priority: .userInitiated) {
            await self.run()
        }
    }

    private func stopIsolated() async {
        if let task = handlerTask {
            task.cancel()
            await task.value // wait until `run()` exits
        }
    }

    // MARK: - Main run loop

    private func run() async {
        do {
            try await openFlow()
            await readLoop()
        } catch {
            log.error("UDP flow handler error: \(error.localizedDescription)")
        }
        await cleanup()
    }

    // MARK: - Flow helpers

    private func openFlow() async throws {
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            udpFlow.open(withLocalEndpoint: nil) { error in
                if let error {
                    continuation.resume(throwing: error)
                } else {
                    continuation.resume(returning: ())
                }
            }
        }
        log.debug("UDP flow opened successfully, local endpoint: \(String(describing: udpFlow.localEndpoint))")
    }

    private func readLoop() async {
        while !Task.isCancelled {
            guard let datagrams = try? await readDatagrams(), !datagrams.isEmpty else { break }

            for (data, endpoint) in datagrams {
                await forwardDatagram(data, to: endpoint)
            }
        }
    }

    private func readDatagrams() async throws -> [(Data, NWEndpoint)] {
        try await withCheckedThrowingContinuation { continuation in
            udpFlow.readDatagramsUniversal { datagrams, error in
                if let error {
                    continuation.resume(throwing: error)
                } else if let datagrams {
                    continuation.resume(returning: datagrams)
                } else {
                    continuation.resume(returning: [])
                }
            }
        }
    }

    // MARK: - Forwarding

    private func forwardDatagram(_ data: Data, to endpoint: NWEndpoint) async {
        // Ensure we have a connection task for this endpoint
        await ensureConnectionTask(for: endpoint)

        // Send the data to the connection task through the channel
        if let sendChannel = sendChannels[endpoint] {
            sendChannel.yield(data)
        } else {
            log.error("No send channel available for endpoint \(endpoint)")
        }
    }

    // MARK: - Connection management

    private func ensureConnectionTask(for endpoint: NWEndpoint) async {
        guard connectionLifecycleTasks[endpoint] == nil else { return }

        let interfaceToUse = endpoint.shouldUseWireguardInterface ? nil : targetInterface

        // Create the send channel for this connection
        let (sendStream, sendContinuation) = AsyncStream<Data>.makeStream()
        sendChannels[endpoint] = sendContinuation

        // Create and store the main connection task
        let connectionTask = Task {
            await handleConnectionLifecycle(for: endpoint, interface: interfaceToUse, sendStream: sendStream)
        }

        connectionLifecycleTasks[endpoint] = connectionTask
        log.debug("Started connection lifecycle task for \(endpoint)")
    }

    private func handleConnectionLifecycle(for endpoint: NWEndpoint, interface: NWInterface?, sendStream: AsyncStream<Data>) async {
        let parameters = NWParameters.udp
        if let interface {
            parameters.requiredInterface = interface
        }
        parameters.allowLocalEndpointReuse = true

        let connection = AsyncConnection(to: endpoint, using: parameters)
        let queue = DispatchQueue(
            label: "ch.protonvpn.plutonium.udp-\(id.uuidString)-\(endpoint)",
            qos: .userInitiated
        )

        connection.start(queue: queue)

        await monitorConnectionStates(connection: connection, endpoint: endpoint, sendStream: sendStream)

        log.debug("Connection lifecycle ended for \(endpoint)")
    }

    /// State monitoring and data forwarding for a connection
    private func monitorConnectionStates(connection: AsyncConnection, endpoint: NWEndpoint, sendStream: AsyncStream<Data>) async {
        stateLoop: for await state in connection.states {
            switch state {
            case .setup:
                log.debug("UDP connection setup for \(endpoint)")
            case .preparing:
                log.debug("UDP connection preparing for \(endpoint)")
            case let .waiting(error):
                log.debug("UDP connection waiting for \(endpoint): \(error.localizedDescription)")
            case .ready:
                log.debug("UDP connection ready for \(endpoint)")
                startDataForwarding(connection: connection, endpoint: endpoint, sendStream: sendStream)
            case let .failed(error):
                log.error("UDP connection failed for \(endpoint): \(error.localizedDescription)")
                break stateLoop
            case .cancelled:
                log.debug("UDP connection cancelled for \(endpoint)")
                break stateLoop
            @unknown default:
                log.debug("UDP connection for \(endpoint) entered an unknown state")
            }
        }

        connection.cancel()
        log.debug("State monitoring ended for \(endpoint)")
    }

    // MARK: - Data forwarding management

    private func startDataForwarding(connection: AsyncConnection, endpoint: NWEndpoint, sendStream: AsyncStream<Data>) {
        // Start sending and receiving tasks in parallel without blocking
        Task {
            await handleSending(connection: connection, endpoint: endpoint, sendStream: sendStream)
        }

        Task {
            await handleReceiving(connection: connection, endpoint: endpoint)
        }

        log.debug("Started parallel data forwarding tasks for \(endpoint)")
    }

    // MARK: - Connection handling

    private func handleSending(connection: AsyncConnection, endpoint: NWEndpoint, sendStream: AsyncStream<Data>) async {
        for await data in sendStream {
            guard !Task.isCancelled else {
                log.debug("Sending task cancelled for \(endpoint)")
                break
            }

            await withCheckedContinuation { (continuation: CheckedContinuation<Void, Never>) in
                connection.send(content: data) { error in
                    if let error {
                        log.error("Failed to send datagram to \(endpoint): \(error.localizedDescription)")
                    }
                    continuation.resume()
                }
            }
        }
        log.debug("Send stream ended for \(endpoint)")
    }

    private func handleReceiving(connection: AsyncConnection, endpoint: NWEndpoint) async {
        while !Task.isCancelled {
            do {
                let (data, isComplete) = try await connection.receiveMessageAsync()
                guard let data, !data.isEmpty else { break }

                // Send the received data back to the flow
                await withCheckedContinuation { (continuation: CheckedContinuation<Void, Never>) in
                    udpFlow.writeDatagramsUniversal([(data, endpoint)]) { error in
                        if let error {
                            log.error("Failed to write response to flow: \(error.localizedDescription)")
                        }
                        continuation.resume()
                    }
                }

                if isComplete { break }
            } catch {
                log.error("Error receiving from \(endpoint): \(error.localizedDescription)")
                break
            }
        }
        log.debug("Receive loop ended for \(endpoint)")
    }

    // MARK: - Cleanup

    private func cleanup() async {
        guard !didCleanup else { return }
        didCleanup = true

        log.debug("Cleaning up \(connectionLifecycleTasks.count) connection lifecycle tasks")

        // Finish all send channels first
        for (endpoint, sendChannel) in sendChannels {
            sendChannel.finish()
            log.debug("Finished send channel for endpoint \(endpoint)")
        }
        sendChannels.removeAll()

        // Cancel all connection lifecycle tasks
        for (endpoint, task) in connectionLifecycleTasks {
            task.cancel()
            log.debug("Cancelled connection lifecycle task for endpoint \(endpoint)")
        }
        connectionLifecycleTasks.removeAll()

        udpFlow.closeReadWithError(nil)
        udpFlow.closeWriteWithError(nil)

        await onClose?()
        log.debug("UDP flow handler cleanup completed")
    }

    // MARK: - Helper methods

    private func cleanupConnection(for endpoint: NWEndpoint) async {
        // Clean up send channel
        if let sendChannel = sendChannels.removeValue(forKey: endpoint) {
            sendChannel.finish()
            log.debug("Finished send channel for endpoint \(endpoint)")
        }

        // Clean up main connection lifecycle task
        if let task = connectionLifecycleTasks.removeValue(forKey: endpoint) {
            task.cancel()
            log.debug("Cleaned up connection lifecycle task for endpoint \(endpoint)")
        }
    }
}

// MARK: - Hashable & Equatable conformance

extension UDPFlowHandler: Hashable {
    nonisolated static func == (lhs: UDPFlowHandler, rhs: UDPFlowHandler) -> Bool {
        lhs.id == rhs.id
    }

    nonisolated func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }
}

private extension IPv4Address {
    static let protonDNS = IPv4Address("10.2.0.1")
}

private extension NWEndpoint {
    var shouldUseWireguardInterface: Bool {
        switch self {
        case let .hostPort(.ipv4(address), _) where address == .protonDNS:
            // TODO: VPNAPPL-2911 - Retrieve DNS settings from WG extension and use here.
            // Traffic to WireGuard DNS server (10.2.0.1) should always go through WireGuard.
            true
        case .hostPort(_, 53):
            // All DNS queries (port 53) should go through WireGuard
            true
        default:
            false
        }
    }
}
