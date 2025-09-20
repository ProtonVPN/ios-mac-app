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
import VPNShared

/// Handles UDP flow copying between network interfaces.
/// One instance per `NEAppProxyUDPFlow`.
/// There will be an individual connection with its own queue per endpoint in the flow, which will be reused throughout the handling of the UDP flow.
final actor UDPFlowHandler: FlowHandler {
    let id = UUID()

    // MARK: - Stored properties

    private let udpFlow: NEAppProxyUDPFlow
    private let vpnInterface: NWInterface
    private let dnsServers: Set<String>
    private let targetInterface: NWInterface
    private let endpointForwardingMode: EndpointForwardingMode
    private var connectionLifecycleTasks: [NWEndpoint: Task<Void, Never>] = [:]
    private var dataForwardingTasks: [NWEndpoint: (sendTask: Task<Void, Never>, receiveTask: Task<Void, Never>)] = [:]
    private var sendChannels: [NWEndpoint: AsyncStream<Data>.Continuation] = [:]

    private var didCleanup = false
    private var onClose: (@Sendable () async -> Void)?

    private var handlerTask: Task<Void, Never>?

    // MARK: - Init

    init(
        udpFlow: NEAppProxyUDPFlow,
        targetInterface: NWInterface,
        vpnInterface: NWInterface, // We always require the VPN interface to manage selective interface options for endpoints and DNS queries.
        dnsServers: Set<String>,
        endpointForwardingMode: EndpointForwardingMode
    ) {
        self.udpFlow = udpFlow
        self.targetInterface = targetInterface
        self.vpnInterface = vpnInterface
        self.dnsServers = dnsServers
        self.endpointForwardingMode = endpointForwardingMode
        logDebug("UDP flow handler initialized for interface \(targetInterface.name)")
    }

    // MARK: - Public

    func start(onClose: @escaping @Sendable () async -> Void) async {
        guard handlerTask == nil else { return }

        self.onClose = onClose
        handlerTask = Task(priority: .userInitiated) {
            await self.run()
        }
    }

    func stop() async {
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
            logError("UDP flow handler error: \(error.localizedDescription)")
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
        logDebug("UDP flow opened successfully, local endpoint: \(String(describing: udpFlow.localEndpoint))")
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
            logError("No send channel available for endpoint \(endpoint)")
        }
    }

    // MARK: - Connection management

    private func ensureConnectionTask(for endpoint: NWEndpoint) async {
        guard connectionLifecycleTasks[endpoint] == nil else { return }

        let interfaceToUse = interfaceFor(endpoint: endpoint)

        logDebug("Using \(interfaceToUse?.name ?? "default") interface for \(endpoint)")

        // Create the send channel for this connection
        let (sendStream, sendContinuation) = AsyncStream<Data>.makeStream()
        sendChannels[endpoint] = sendContinuation

        // Create and store the main connection task
        let connectionTask = Task {
            await handleConnectionLifecycle(for: endpoint, interface: interfaceToUse, sendStream: sendStream)
        }

        connectionLifecycleTasks[endpoint] = connectionTask
        logDebug("Started connection lifecycle task for \(endpoint)")
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

        logDebug("Connection lifecycle ended for \(endpoint)")
    }

    /// State monitoring and data forwarding for a connection
    private func monitorConnectionStates(connection: AsyncConnection, endpoint: NWEndpoint, sendStream: AsyncStream<Data>) async {
        stateLoop: for await state in connection.states {
            switch state {
            case .setup:
                logDebug("UDP connection setup for \(endpoint)")
            case .preparing:
                logDebug("UDP connection preparing for \(endpoint)")
            case let .waiting(error):
                logDebug("UDP connection waiting for \(endpoint): \(error.localizedDescription)")
            case .ready:
                logDebug("UDP connection ready for \(endpoint)")
                startDataForwarding(connection: connection, endpoint: endpoint, sendStream: sendStream)
            case let .failed(error):
                logDebug("UDP connection failed for \(endpoint): \(error.localizedDescription)")
                break stateLoop
            case .cancelled:
                logDebug("UDP connection cancelled for \(endpoint)")
                break stateLoop
            @unknown default:
                logDebug("UDP connection for \(endpoint) entered an unknown state")
            }
        }

        connection.cancel()
        logDebug("State monitoring ended for \(endpoint)")
    }

    // MARK: - Data forwarding management

    private func startDataForwarding(connection: AsyncConnection, endpoint: NWEndpoint, sendStream: AsyncStream<Data>) {
        // Start sending and receiving tasks in parallel, tracking them for proper cleanup
        let sendTask = Task {
            await handleSending(connection: connection, endpoint: endpoint, sendStream: sendStream)
        }

        let receiveTask = Task {
            await handleReceiving(connection: connection, endpoint: endpoint)
        }

        dataForwardingTasks[endpoint] = (sendTask, receiveTask)
        logDebug("Started parallel data forwarding tasks for \(endpoint)")
    }

    // MARK: - Connection handling

    private func handleSending(connection: AsyncConnection, endpoint: NWEndpoint, sendStream: AsyncStream<Data>) async {
        for await data in sendStream {
            guard !Task.isCancelled else {
                logDebug("Sending task cancelled for \(endpoint)")
                break
            }

            await withCheckedContinuation { (continuation: CheckedContinuation<Void, Never>) in
                connection.send(content: data) { [weak self] error in
                    if let error {
                        self?.logError("Failed to send datagram to \(endpoint): \(error.localizedDescription)")
                    }
                    continuation.resume()
                }
            }
        }
        logDebug("Send stream ended for \(endpoint)")
    }

    private func handleReceiving(connection: AsyncConnection, endpoint: NWEndpoint) async {
        while !Task.isCancelled {
            do {
                let (data, isComplete) = try await connection.receiveMessageAsync()
                guard let data, !data.isEmpty else { break }

                // Send the received data back to the flow
                await withCheckedContinuation { (continuation: CheckedContinuation<Void, Never>) in
                    udpFlow.writeDatagramsUniversal([(data, endpoint)]) { [weak self] error in
                        if let error {
                            self?.logError("Failed to write response to flow: \(error.localizedDescription)")
                        }
                        continuation.resume()
                    }
                }

                if isComplete { break }
            } catch {
                logError("Error receiving from \(endpoint): \(error.localizedDescription)")
                break
            }
        }
        logDebug("Receive loop ended for \(endpoint)")
    }

    // MARK: - Cleanup

    private func cleanup() async {
        guard !didCleanup else { return }
        didCleanup = true

        logDebug("Cleaning up \(connectionLifecycleTasks.count) connection lifecycle tasks and \(dataForwardingTasks.count) data forwarding task pairs")

        // Cancel all data forwarding tasks first
        for (endpoint, tasks) in dataForwardingTasks {
            tasks.sendTask.cancel()
            tasks.receiveTask.cancel()
            logDebug("Cancelled data forwarding tasks for endpoint \(endpoint)")
        }
        dataForwardingTasks.removeAll()

        // Finish all send channels
        for (endpoint, sendChannel) in sendChannels {
            sendChannel.finish()
            logDebug("Finished send channel for endpoint \(endpoint)")
        }
        sendChannels.removeAll()

        // Cancel all connection lifecycle tasks
        for (endpoint, task) in connectionLifecycleTasks {
            task.cancel()
            logDebug("Cancelled connection lifecycle task for endpoint \(endpoint)")
        }
        connectionLifecycleTasks.removeAll()

        udpFlow.closeReadWithError(nil)
        udpFlow.closeWriteWithError(nil)

        await onClose?()
        logDebug("UDP flow handler cleanup completed")
    }

    // MARK: - Helper methods

    private func cleanupConnection(for endpoint: NWEndpoint) async {
        // Cancel data forwarding tasks
        if let tasks = dataForwardingTasks.removeValue(forKey: endpoint) {
            tasks.sendTask.cancel()
            tasks.receiveTask.cancel()
            logDebug("Cancelled data forwarding tasks for endpoint \(endpoint)")
        }

        // Clean up send channel
        if let sendChannel = sendChannels.removeValue(forKey: endpoint) {
            sendChannel.finish()
            logDebug("Finished send channel for endpoint \(endpoint)")
        }

        // Clean up main connection lifecycle task
        if let task = connectionLifecycleTasks.removeValue(forKey: endpoint) {
            task.cancel()
            logDebug("Cleaned up connection lifecycle task for endpoint \(endpoint)")
        }
    }

    private func interfaceFor(endpoint: NWEndpoint) -> NWInterface? {
        // If the endpoint needs to be forwarded through the Wireguard network, it goes always to VPN interface.
        if endpoint.shouldAlwaysUseVpnInterface(dnsServers: dnsServers) {
            return vpnInterface
        }
        // If the connection to the endpoint should be forwarded, the target interface will be used.
        if endpoint.shouldForward(endpointForwardingMode) {
            return targetInterface
        }
        // Otherwise, the default interface that has already been set on the connection will be used.
        return nil
    }
}

enum EndpointForwardingMode {
    case all
    case only(ips: Set<String>)
}

// MARK: - Extensions

extension UDPFlowHandler: Hashable {
    nonisolated static func == (lhs: UDPFlowHandler, rhs: UDPFlowHandler) -> Bool {
        lhs.id == rhs.id
    }

    nonisolated func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }
}

private extension NWEndpoint {
    func shouldForward(_ mode: EndpointForwardingMode) -> Bool {
        switch mode {
        case .all:
            return true
        case let .only(ips: ips):
            guard let ipv4String else {
                return false
            }
            return ips.contains(ipv4String)
        }
    }
}
