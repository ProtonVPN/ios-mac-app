//
//  Created on 02/06/2025 by Shahin Katebi.
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
import NetworkExtension
import Network

final class TCPFlowHandler: @unchecked Sendable {

    private static let maxBufferSize = 512 * 1024  // 512 KB

    let connection: NWConnection
    let flow: NEAppProxyTCPFlow
    var onClose: (() -> Void)?
    
    // Add unique identifier for Set operations
    private let id = UUID()

    init?(flow: NEAppProxyTCPFlow, interface: NWInterface) {
        self.flow = flow
        let parameters = NWParameters.tcp
        parameters.requiredInterface = interface

        guard let remoteEndpoint = flow.remoteEndpoint else {
            log.error("Cannot get remote endpoint for TCP flow")
            return nil
        }
        log.debug("Creating TCP connection to: \(remoteEndpoint)")
        self.connection = NWConnection(to: remoteEndpoint, using: parameters)
    }

    func start() {
        connection.stateUpdateHandler = { [weak self] state in
            self?.handleConnectionState(state)
        }

        connection.start(queue: .global(qos: .default))
    }

    private func handleConnectionState(_ state: NWConnection.State) {
        switch state {
        case .ready:
            log.info("TCP flow handler connection ready")
            startDataForwarding()
        case .failed(let error):
            log.error("TCP flow handler connection failed: \(error.localizedDescription)")
            close()
        case .cancelled:
            log.info("TCP flow handler connection cancelled")
            close()
        default:
            break
        }
    }

    private func startDataForwarding() {

        // First, open the TCP flow, sending nil as localEndpoint since the flow already has specific endpoint.
        flow.open(withLocalEndpoint: nil) { [weak self] error in
            if let error = error {
                log.error("Failed to open TCP flow: \(error.localizedDescription)")
                self?.close()
                return
            }

            log.info("TCP flow opened successfully - starting bidirectional forwarding")

            // Forward data from app to tunnel
            self?.forwardFromFlowToConnection()

            // Forward data from tunnel to app
            self?.forwardFromConnectionToFlow()
        }
    }

    private func forwardFromFlowToConnection() {
        flow.readData { [weak self] data, error in
            guard let self = self else { return }

            if let error = error {
                log.error("Error reading from TCP flow: \(error.localizedDescription)")
                self.close()
                return
            }

            guard let data = data, !data.isEmpty else {
                log.info("TCP flow closed by client")
                self.close()
                return
            }

            self.connection.send(content: data, completion: .contentProcessed { sendError in
                if let sendError = sendError {
                    log.error("Error sending to tunnel: \(sendError.localizedDescription)")
                    self.close()
                } else {
                    // Continue reading
                    self.forwardFromFlowToConnection()
                }
            })
        }
    }

    private func forwardFromConnectionToFlow() {
        connection.receive(minimumIncompleteLength: 1, maximumLength: Self.maxBufferSize) { [weak self] data, _, isDone, error in
            guard let self = self else { return }

            if let error = error {
                log.error("Error receiving from tunnel: \(error.localizedDescription)")
                self.close()
                return
            }

            guard let data = data, !data.isEmpty else {
                if isDone {
                    self.close()
                }
                return
            }

            self.flow.write(data) { writeError in
                if let writeError {
                    log.error("Error writing to TCP flow: \(writeError.localizedDescription)")
                    self.close()
                    return
                }
                if isDone {
                    // Done
                    self.close()
                } else {
                    // Continue receiving
                    self.forwardFromConnectionToFlow()
                }
            }
        }
    }

    private func close() {
        flow.closeWriteWithError(nil)
        connection.cancel()
        onClose?()
        log.info("TCP tunnel connection closed")
    }
}

// MARK: - Hashable & Equatable
extension TCPFlowHandler: Hashable {
    static func == (lhs: TCPFlowHandler, rhs: TCPFlowHandler) -> Bool {
        return lhs.id == rhs.id
    }

    func hash(into hasher: inout Hasher) {
        id.hash(into: &hasher)
    }
}
