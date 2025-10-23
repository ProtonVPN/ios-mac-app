//
//  Created on 04/10/2025 by Adam Viaud.
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

import Besogne
import Darwin
import Foundation
import NetworkExtension
import NetworkingErgonomics
import OSLog

enum TCPFlowHandlerError: Swift.Error {
    case invalidError
    case connectionFailed
    case other(any Error)
    case flowOpenFailed(any Error)
    case setupFailed(SocketError)
    case startFailed(SocketError)
}

final class TCPFlowHandler: FlowHandler, Sendable {
    let id: UUID
    let flow: NEAppProxyTCPFlow

    private let socketQueue = DispatchQueue(label: "ch.protonvpn.mac.transparent-proxy.tcp.socket", qos: .userInitiated)
    private let flowQueue = DispatchQueue(label: "ch.protonvpn.mac.transparent-proxy.tcp.flow", qos: .userInitiated)

    private let isRunning = OSAllocatedUnfairLock(initialState: false)

    private var port: UInt16? {
        switch flow.remoteEndpoint {
        case let .hostPort(_, port: port):
            port.rawValue
        default:
            nil
        }
    }

    init(flow: NEAppProxyTCPFlow) {
        self.id = UUID()
        self.flow = flow
    }

    func setup() throws(TCPFlowHandlerError) -> Socket<TCP, Opened> {
        guard let remoteEndpoint = flow.remoteEndpoint else {
            throw .invalidError
        }

        Logger.tcp.debug("Setuping TCP Flow: \(self.flow, privacy: .public)")

        // Create and configure socket
        do {
            let socket = try Socket.tcp()

            // Enable TCP_NODELAY for lower latency
            try socket.setNoDelay(true)

            // Enable SO_KEEPALIVE
            try socket.setKeepAlive(true)

            // Set socket buffer sizes
            try socket.setRecvBufferSize(262_144) // 256KB
            try socket.setSendBufferSize(262_144) // 256KB

            // Disable SIGPIPE
            try socket.setNoSigPipe(true)

            // Bind to en0 interface
            try socket.bindToInterface(name: "en0")
            Logger.tcp.debug("Socket bound to en0")

            // Connect to destination
            let timeout = timeval(tv_sec: 5, tv_usec: 0)
            try socket.setRecvTimeout(timeout)
            try socket.setSendTimeout(timeout)

            return try socket.connect(to: sockaddr_from_endpoint(remoteEndpoint)) // maybe add the connectTimeout as well?
        } catch {
            throw .setupFailed(error)
        }
    }

    func start(socket: consuming Socket<TCP, Opened>, completion: @escaping (Result<Void, TCPFlowHandlerError>) -> Void) {
        let signposter = OSSignposter()
        let signpostID = signposter.makeSignpostID()

        let signpostState = signposter.beginInterval("TCP Flow Handling", id: signpostID)

        Logger.udp.debug("Starting Flow: \(self.flow, privacy: .public)")

        // Start bidirectional proxy using GCD
        do {
            try socket.split { sendHalf, recvHalf in
                isRunning.withLock { $0 = true }

                let group = DispatchGroup()

                group.enter()
                self.socketQueue.async {
                    self.proxyAppToSocket(socket: sendHalf)
                    group.leave()
                }

                group.enter()
                self.flowQueue.async {
                    self.proxySocketToApp(socket: recvHalf)
                    group.leave()
                }

                // Wait for completion
                group.notify(queue: .global()) {
                    self.cleanup()
                    signposter.endInterval("TCP Flow Handling", signpostState)
                    completion(.success(()))
                }
            }
        } catch {
            completion(.failure(.startFailed(error)))
        }
    }

    func openFlow(completion: @escaping (Result<Void, TCPFlowHandlerError>) -> Void) {
        flow.openUniversal(withLocalEndpoint: nil) { error in
            if let error {
                completion(.failure(.flowOpenFailed(error)))
            } else {
                Logger.tcp.debug("Flow open error: \(error)")
                completion(.success(()))
            }
        }
    }

    func stop() {
        cleanup()
    }

    private func cleanup() {
        isRunning.withLock { $0 = false }

        flow.closeReadWithError(nil)
        flow.closeWriteWithError(nil)

        Logger.tcp.debug("Cleanup completed")
    }

    private func proxyAppToSocket(socket: borrowing SocketSendHalf<TCP>) {
        Logger.tcp.debug("Starting app to socket proxy")
        defer {
            Logger.tcp.debug("Closing flow write direction")
            flow.closeReadWithError(nil)
        }

        let semaphore = DispatchSemaphore(value: 0)

        while isRunning.withLock({ $0 }) {
            var readData: Data?
            var readError: Error?

            // Read from app flow
            flow.readData { data, error in
                readData = data
                readError = error
                semaphore.signal()
            }

            let semaphoreWaitResult = semaphore.wait(timeout: .now() + .seconds(3))

            if case .timedOut = semaphoreWaitResult {
                Logger.tcp.debug("Flow Read Data timeout")
                break
            }

            if let error = readError {
                Logger.tcp.debug("Error reading from app: \(error)")
                break
            }

            guard let data = readData, !data.isEmpty else {
                Logger.tcp.debug("No more data from app")
                break
            }

            do {
                try socket.send(data: data)
            } catch SocketError.tcpSendFailed(.closedByRemote) {
                Logger.tcp.debug("Socket closed during write")
                return
            } catch {
                Logger.tcp.debug("Socket send error: \(error)")
                return
            }
        }
    }

    private func proxySocketToApp(socket: borrowing SocketRecvHalf<TCP>) {
        Logger.tcp.debug("Starting socket to app proxy")

        let bufferSize = 65536
        let buffer = UnsafeMutablePointer<UInt8>.allocate(capacity: bufferSize)
        defer {
            buffer.deallocate()
            Logger.tcp.debug("Closing flow write direction")
            flow.closeWriteWithError(nil)
        }

        let semaphore = DispatchSemaphore(value: 0)

        while isRunning.withLock({ $0 }) {
            do {
                // Read from socket
                let data = try socket.receive(buffer: buffer, bufferSize: bufferSize, noCopy: true)

                if !data.isEmpty {
                    var writeError: Error?

                    // Write to app flow
                    flow.write(data) { error in
                        writeError = error
                        semaphore.signal()
                    }

                    let semaphoreWaitResult = semaphore.wait(timeout: .now() + .seconds(1))

                    if case .timedOut = semaphoreWaitResult {
                        Logger.tcp.debug("Flow Write Data timeout")
                        break
                    }

                    if let error = writeError {
                        Logger.tcp.debug("Error writing to app: \(error)")
                        break
                    }
                }
            } catch .tcpRecvInterrupted {
                continue
            } catch .tcpRecvFailed(.closedByRemote) {
                Logger.tcp.debug("Socket closed by remote (EOF)")
                break
            } catch {
                Logger.tcp.debug("Socket recv error: \(error)")
                break
            }
        }
    }
}

extension TCPFlowHandler: Hashable {
    static func == (lhs: TCPFlowHandler, rhs: TCPFlowHandler) -> Bool {
        lhs === rhs
    }

    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }
}

func sockaddr_from_endpoint(_ endpoint: NWEndpoint) -> sockaddr_in {
    let remoteIP = endpoint.ipv4String ?? ""
    let port = endpoint.port

    var addr = sockaddr_in()
    addr.sin_family = sa_family_t(AF_INET)
    addr.sin_port = in_port_t(port ?? 80).bigEndian
    inet_pton(AF_INET, remoteIP, &addr.sin_addr)

    return addr
}

extension NWEndpoint {
    var port: UInt16? {
        switch self {
        case let .hostPort(_, port: port):
            port.rawValue
        default:
            nil
        }
    }
}
