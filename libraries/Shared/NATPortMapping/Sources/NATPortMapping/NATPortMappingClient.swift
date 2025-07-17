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

class NATPortMappingClient {
    static let NAT_PMP_PORT: UInt16 = 5351
    static let MAX_RETRIES: Int = 9 // per RFC: 250ms, 500ms, 1s, 2s, 4s, 8s, 16s, 32s, 64s
    static let RETRY_DELAY: TimeInterval = 0.25

    private var gatewayAddress: String
    private let queue = DispatchQueue(label: "ch.proton.nat-pmp-client")

    // MARK: - Init

    init(gatewayAddress: String) {
        self.gatewayAddress = gatewayAddress
    }

    func setGatewayAddress(_ gatewayAddress: String) {
        self.gatewayAddress = gatewayAddress
    }

    func makeConnection() -> AsyncConnection {
        // Create UDP connection to gateway:5351
        let endpoint = NWEndpoint.hostPort(
            host: NWEndpoint.Host(gatewayAddress),
            port: NWEndpoint.Port(integerLiteral: Self.NAT_PMP_PORT)
        )

        return AsyncConnection(to: endpoint, using: .udp)
    }

    func requestPortMapping(
        portProtocol: PortMappingProtocol = .udp,
        internalPort: UInt16,
        externalPort: UInt16 = 0,
        lifetime: UInt32 = 7200
    ) async throws -> PortMappingPacketResponse {
        let connection = makeConnection()
        connection.start(queue: queue)

        let portMappingRequestPacket = createPortMappingRequest(
            portProtocol: portProtocol,
            internalPort: internalPort,
            externalPort: externalPort,
            lifetime: lifetime
        )
        return try await monitorConnectionStates(connection: connection, portMappingRequestPacket: portMappingRequestPacket)
    }

    func deletePortMapping(
        internalPort: UInt16,
        portProtocol: PortMappingProtocol
    ) async throws {
        // Send request with lifetime = 0 to delete
        _ = try await requestPortMapping(
            portProtocol: portProtocol,
            internalPort: internalPort,
            lifetime: 0
        )
    }

    // MARK: - Private

    private func monitorConnectionStates(connection: AsyncConnection, portMappingRequestPacket: Data) async throws -> PortMappingPacketResponse {
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
                for attempt in 0 ..< Self.MAX_RETRIES {
                    do {
                        try await send(connection: connection, portMappingRequestPacket: portMappingRequestPacket)
                        return try await receive(connection: connection, attempt: attempt)
                    } catch {
                        if error as? NATPortMappingError == .timeoutError {
                            // retry on timeoutErrors given retries left
                            continue
                        }
                        throw error
                    }
                }
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

        connection.cancel()
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
        let receiveTask = Task {
            let (data, _) = try await connection.receiveMessageAsync()
            try Task.checkCancellation()
            guard let data, !data.isEmpty else {
                throw NATPortMappingError.invalidResponse
            }
            // TODO: map ICMP request?
            return try PortMappingPacketResponse(from: data)
        }

        // wait for the response for a predefined timeout
        let retryDelay = pow(Self.RETRY_DELAY, Double(attempt + 1))
        let timeoutTask = Task {
            try await Task.sleep(for: .seconds(retryDelay))
            receiveTask.cancel()
            // if receive task was cancelled due to timeout, throw timeoutError
            throw NATPortMappingError.timeoutError
        }

        let response = try await receiveTask.value
        // if we received a response before timeout, cancel timeout task
        timeoutTask.cancel()
        return response
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

enum NATPortMappingError: Error {
    case invalidResponse
    case malformedPacket
    case timeoutError
    case mappingFailed
    case connectionClosed
}
