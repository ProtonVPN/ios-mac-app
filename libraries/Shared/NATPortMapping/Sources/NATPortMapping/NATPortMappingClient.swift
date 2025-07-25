//
//  Created on 16/07/2025 by Max Kupetskyi.
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
import VPNShared

final class NATPortMappingClient: Sendable {
    static let NAT_PMP_PORT: UInt16 = 5351
    static let MAX_RETRIES: Int = 9 // per RFC: 250ms, 500ms, 1s, 2s, 4s, 8s, 16s, 32s, 64s
    static let RETRY_DELAY: TimeInterval = 0.25

    private let queue = DispatchQueue(label: "ch.proton.nat-pmp-client")

    // MARK: - Init

    init() {}

    func requestPortMapping(
        gatewayAddress: String,
        portProtocol: PortMappingProtocol = .udp,
        internalPort: UInt16,
        externalPort: UInt16 = 0,
        lifetime: UInt32 = 7200,
        currentMappingExpirationDate: Date? = nil
    ) async throws -> PortMappingPacketResponse {
        let portMappingRequestPacket = createPortMappingRequest(
            portProtocol: portProtocol,
            internalPort: internalPort,
            externalPort: externalPort,
            lifetime: lifetime
        )

        for attempt in 0 ..< Self.MAX_RETRIES {
            // if mapping expired throw
            if let currentMappingExpirationDate, Date() > currentMappingExpirationDate {
                throw NATPortMappingError.mappingFailed
            }

            let connection = Self.makeConnection(gatewayAddress: gatewayAddress)
            connection.start(queue: queue)

            do {
                let response = try await monitorConnectionStates(
                    connection: connection,
                    portMappingRequestPacket: portMappingRequestPacket,
                    attempt: attempt
                )
                connection.cancel()
                return response
            } catch NATPortMappingError.timeoutError {
                // retry on timeoutErrors given retries left
                continue
            } catch {
                connection.cancel()
                throw error
            }
        }

        throw NATPortMappingError.mappingFailed
    }

    // MARK: - Private

    private static func makeConnection(gatewayAddress: String) -> AsyncConnection {
        // Create UDP connection to gateway:5351
        let endpoint = NWEndpoint.hostPort(
            host: NWEndpoint.Host(gatewayAddress),
            port: NWEndpoint.Port(integerLiteral: Self.NAT_PMP_PORT)
        )

        return AsyncConnection(to: endpoint, using: .udp)
    }

    private func monitorConnectionStates(connection: AsyncConnection, portMappingRequestPacket: Data, attempt: Int) async throws -> PortMappingPacketResponse {
        stateLoop: for await state in connection.states {
            switch state {
            case .setup:
                log.debug("NAT-PMP connection setup for \(connection.nwEndpoint)")
            case .preparing:
                log.debug("NAT-PMP connection preparing for \(connection.nwEndpoint)")
            case let .waiting(error):
                log.debug("NAT-PMP connection waiting for \(connection.nwEndpoint): \(error.localizedDescription)")
            case .ready:
                log.debug("NAT-PMP connection ready for \(connection.nwEndpoint)")
                try await send(connection: connection, portMappingRequestPacket: portMappingRequestPacket)
                return try await receive(connection: connection, attempt: attempt)
            case let .failed(error):
                log.error("NAT-PMP connection failed for \(connection.nwEndpoint): \(error.localizedDescription)")
                break stateLoop
            case .cancelled:
                log.debug("NAT-PMP connection cancelled for \(connection.nwEndpoint)")
                break stateLoop
            @unknown default:
                log.debug("NAT-PMP connection for \(connection.nwEndpoint) entered an unknown state")
            }
        }

        log.debug("NAT-PMP State monitoring ended for \(connection.nwEndpoint)")
        throw NATPortMappingError.connectionClosed
    }

    private func send(connection: AsyncConnection, portMappingRequestPacket: Data) async throws {
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            connection.send(content: portMappingRequestPacket, completion: { error in
                if let error {
                    log.error("Failed to send NAT-PMP request: \(error.localizedDescription)")
                    continuation.resume(throwing: error)
                }
                continuation.resume()
            })
        }
    }

    private func receive(connection: AsyncConnection, attempt: Int) async throws -> PortMappingPacketResponse {
        let retryDelay = Self.RETRY_DELAY * pow(2, Double(attempt))
        let attemptStart = Date()
        return try await withThrowingTaskGroup(of: PortMappingPacketResponse.self) { group in
            // Add receive task
            group.addTask {
                let (data, _) = try await connection.receiveMessageAsync()
                if Date() > attemptStart.addingTimeInterval(retryDelay) {
                    // this might happen if timeout is reached
                    connection.cancel()
                    throw NATPortMappingError.timeoutError
                }
                guard let data, !data.isEmpty else {
                    throw NATPortMappingError.invalidResponse
                }
                return try PortMappingPacketResponse(from: data)
            }

            // Add timeout task
            group.addTask {
                try await Task.sleep(for: .seconds(retryDelay))
                connection.cancel()
                throw NATPortMappingError.timeoutError
            }

            // Return the first result (either success or timeout)
            guard let result = try await group.next() else {
                throw NATPortMappingError.timeoutError
            }

            group.cancelAll()
            return result
        }
    }

    private func createPortMappingRequest(
        portProtocol: PortMappingProtocol,
        internalPort: UInt16,
        externalPort: UInt16,
        lifetime: UInt32
    ) -> Data {
        let packet = PortMappingPacketRequest(
            portProtocol: portProtocol,
            internalPort: internalPort,
            externalPort: externalPort,
            lifetime: lifetime
        )
        return packet.serialize()
    }
}

public enum NATPortMappingError: Error {
    case invalidResponse
    case malformedPacket
    case timeoutError
    case mappingFailed
    case connectionClosed
}
