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
    private var connections: [NWEndpoint: NWConnection] = [:]

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
        let interfaceToUse = endpoint.shouldUseWireguardInterface ? nil : targetInterface
        let connection = await connectionForEndpoint(endpoint, interface: interfaceToUse)

        await withCheckedContinuation { (continuation: CheckedContinuation<Void, Never>) in
            connection.send(content: data, completion: .contentProcessed { error in
                if let error {
                    log.error("Failed to send datagram to \(endpoint): \(error.localizedDescription)")
                    // Consider: should this stop the handler or retry?
                }
                continuation.resume()
            })
        }
    }

    // MARK: - Connection management

    private func connectionForEndpoint(_ endpoint: NWEndpoint, interface: NWInterface?) async -> NWConnection {
        if let existing = connections[endpoint] {
            return existing
        }

        let parameters = NWParameters.udp
        if let interface {
            parameters.requiredInterface = interface
        }
        parameters.allowLocalEndpointReuse = true

        let connection = NWConnection(to: endpoint, using: parameters)

        let queue = DispatchQueue(
            label: "ch.protonvpn.plutonium.udp-\(id.uuidString)-\(endpoint)",
            qos: .userInitiated
        )

        connection.stateUpdateHandler = { [weak self] state in
            Task { [weak self] in
                await self?.handleStateUpdate(state, connection: connection, endpoint: endpoint)
            }
        }

        connection.start(queue: queue)
        connections[endpoint] = connection
        return connection
    }

    /// Isolated handler for connection state changes.
    private func handleStateUpdate(
        _ state: NWConnection.State,
        connection: NWConnection,
        endpoint: NWEndpoint
    ) async {
        switch state {
        case .setup:
            log.debug("UDP connection setup for \(endpoint)")
        case .preparing:
            log.debug("UDP connection preparing for \(endpoint)")
        case let .waiting(error):
            log.debug("UDP connection waiting for \(endpoint): \(error.localizedDescription)")
        case .ready:
            log.debug("UDP connection ready for \(endpoint)")
            await receiveLoop(from: connection, endpoint: endpoint)
        case let .failed(error):
            log.error("UDP connection failed for \(endpoint): \(error.localizedDescription)")
            await cleanupConnection(for: endpoint)
        case .cancelled:
            log.debug("UDP connection cancelled for \(endpoint)")
            await cleanupConnection(for: endpoint)
        @unknown default:
            log.debug("UDP connection for \(endpoint) entered an unknown state")
        }
    }

    // MARK: - Receiving responses

    private func receiveLoop(from connection: NWConnection, endpoint: NWEndpoint) async {
        while !Task.isCancelled {
            do {
                let (data, isComplete) = try await connection.receiveMessageAsync()
                guard let data, !data.isEmpty else { break }

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
    }

    // MARK: - Cleanup

    private func cleanup() async {
        guard !didCleanup else { return }
        didCleanup = true

        log.debug("Cleaning up \(connections.count) connections")

        for (endpoint, connection) in connections {
            connection.cancel()
            log.debug("Cleaned up connection for endpoint \(endpoint)")
        }
        connections.removeAll()

        udpFlow.closeReadWithError(nil)
        udpFlow.closeWriteWithError(nil)

        await onClose?()
        log.debug("UDP flow handler cleanup completed")
    }

    // MARK: - Helper methods

    private func cleanupConnection(for endpoint: NWEndpoint) async {
        if let connection = connections.removeValue(forKey: endpoint) {
            connection.cancel()
            log.debug("Cleaned up connection for endpoint \(endpoint)")
        }
    }
}

// MARK: - Small helpers

private extension NWConnection {
    /// Async wrapper around `receiveMessage`.
    func receiveMessageAsync() async throws -> (Data?, Bool) {
        try await withCheckedThrowingContinuation { cont in
            receiveMessage { data, _, isComplete, error in
                if let error {
                    cont.resume(throwing: error)
                } else {
                    cont.resume(returning: (data, isComplete))
                }
            }
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

private extension NWEndpoint {
    var shouldUseWireguardInterface: Bool {
        guard case let .hostPort(host, _) = self else { return false }

        // TODO: VPNAPPL-2911 - Retrieve DNS settings from WG extension and use here.

        // Traffic to WireGuard DNS server (10.2.0.1) should always go through WireGuard.
        if case let .ipv4(address) = host, address == IPv4Address("10.2.0.1") {
            return true
        }
        return false
    }
}
