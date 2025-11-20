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
import Logging
import NetworkExtension
import NetworkingErgonomics
import OSLog

enum UDPFlowHandlerError: Swift.Error {
    case sendFailed
    case setupFailed(SocketError)
    case startFailed(SocketError)
    case flowOpenFailed(any Error)
    case expectedFlowFailure
    case other(any Error)
}

final class UDPFlowHandler: FlowHandler, Sendable {
    let id: UUID
    let flow: NEAppProxyUDPFlow

    private static let socketRecvSendBufferSize: CInt = 524_288 // 512 KiB
    private static let socketRecvTimeout: timeval = .init(tv_sec: 0, tv_usec: 100_000)
    private static let flowOperationDataTimeout: DispatchTimeInterval = .seconds(3)

    private let socketQueue = DispatchQueue(label: "ch.protonvpn.mac.transparent-proxy.udp.socket", qos: .userInitiated)
    private let flowQueue = DispatchQueue(label: "ch.protonvpn.mac.transparent-proxy.udp.flow", qos: .userInitiated)

    private let isRunning = OSAllocatedUnfairLock(initialState: false)

    init(flow: NEAppProxyUDPFlow) {
        self.id = UUID()
        self.flow = flow
    }

    static func localEndpoint(with socket: borrowing Socket<NetworkingErgonomics.UDP, Opened>) throws -> NWEndpoint {
        let localAddr = try socket.localEndpoint
        let localPort = UInt16(localAddr.sin_port).byteSwapped

        Logger.udp.debug("Socket bound to local port: \(localPort)")

        return NWEndpoint.hostPort(host: "0.0.0.0", port: .init(rawValue: localPort)!)
    }

    func setup() throws(UDPFlowHandlerError) -> Socket<NetworkingErgonomics.UDP, Opened> {
        // swiftformat:disable:next redundantSelf
        Logger.tcp.debug("Setuping UDP Flow: \(self.flow)")

        do {
            let socket = try Socket.udp()

            // Increase socket buffer sizes
            try socket.setSendBufferSize(Self.socketRecvSendBufferSize)
            try socket.setRecvBufferSize(Self.socketRecvSendBufferSize)

            // Enable SO_REUSEADDR and SO_REUSEPORT
            try socket.setReuseAddr(true)
            try socket.setReusePort(true)

            // Disable SIGPIPE
            try socket.setNoSigPipe(true)

            // Set receive timeout to avoid indefinite blocking
            try socket.setRecvTimeout(Self.socketRecvTimeout)

            Logger.udp.debug("Raw Socket created")

            // Bind to en0
            try socket.bindToInterface(name: "en0")
            Logger.udp.debug("Socket bound to en0")

            return try socket.bindLocally()
        } catch {
            throw .setupFailed(error)
        }
    }

    /// Start and launch the UDP flow handling process. Completion handler is called when the handler has been processed.
    /// - Parameters:
    ///   - socket: a UDP socket in an opened state that will be consumed by this method.
    ///   - completion: a completion handler called once the flow has been processed, successfully or not.
    func start(socket: consuming Socket<NetworkingErgonomics.UDP, Opened>, completion: @escaping (Result<Void, UDPFlowHandlerError>) -> Void) {
        let signposter = OSSignposter()
        let signpostID = signposter.makeSignpostID()

        let signpostState = signposter.beginInterval("UDP Flow Handling", id: signpostID)

        // swiftformat:disable:next redundantSelf
        Logger.udp.debug("Starting Flow: \(self.flow)")

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
                    signposter.endInterval("UDP Flow Handling", signpostState)
                    completion(.success(()))
                }
            }
        } catch {
            completion(.failure(.startFailed(error)))
        }
    }

    func openFlow(localFlowEndpoint: NWEndpoint, completion: @escaping (Result<Void, UDPFlowHandlerError>) -> Void) {
        flow.openUniversal(withLocalEndpoint: localFlowEndpoint) { error in
            if let error = error as? NSError {
                if error.isPotentialQUICProbingError {
                    Logger.udp.debug("Flow closed immediately by app (normal QUIC probing)")
                    completion(.failure(.expectedFlowFailure))
                } else {
                    Logger.udp.debug("Flow open error: \(error)")
                    completion(.failure(.flowOpenFailed(error)))
                }
            } else {
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

        Logger.udp.debug("Cleanup completed")
    }

    private func proxyAppToSocket(socket: borrowing SocketSendHalf<NetworkingErgonomics.UDP>) {
        Logger.udp.debug("Starting app to socket proxy")

        let group = DispatchGroup()

        while isRunning.withLock({ $0 }) {
            var readDatagrams: [(Data, NWEndpoint)]?
            var readError: Error?

            // Read datagrams from app
            group.enter()
            flow.readDatagramsUniversal { datagrams, error in
                readDatagrams = datagrams
                readError = error
                group.leave()
            }

            let groupWaitResult = group.wait(timeout: .now() + Self.flowOperationDataTimeout)

            if case .timedOut = groupWaitResult {
                Logger.tcp.debug("Flow Read Data timeout")
                break
            }

            if let error = readError {
                Logger.udp.debug("Error reading datagrams: \(error)")
                break
            }

            guard let datagrams = readDatagrams, !datagrams.isEmpty else {
                Logger.udp.debug("No more datagrams from app")
                break
            }

            // Send all datagrams
            for (data, endpoint) in datagrams {
                sendDatagram(socket: socket, data: data, to: endpoint)
            }
        }
    }

    private func proxySocketToApp(socket: borrowing SocketRecvHalf<NetworkingErgonomics.UDP>) {
        Logger.udp.debug("Starting socket to app proxy")

        let bufferSize = 65536
        var buffer = UnsafeMutablePointer<UInt8>.allocate(capacity: bufferSize)
        defer {
            buffer.deallocate()
            Logger.udp.debug("Socket to app proxy ended")
        }

        let group = DispatchGroup()

        while isRunning.withLock({ $0 }) {
            do {
                var senderAddr = sockaddr_in()
                let data = try socket.receive(buffer: &buffer, bufferSize: bufferSize, senderAddr: &senderAddr, noCopy: true)

                let senderEndpoint = sockaddrToNWEndpoint(&senderAddr)
                var writeError: Error?

                // Write to app
                group.enter()
                flow.writeDatagramsUniversal([(data, senderEndpoint)]) { error in
                    writeError = error
                    group.leave()
                }

                // it shouldn't take too long to write data to the flow
                let groupWaitResu = group.wait(timeout: .now() + Self.flowOperationDataTimeout)

                if case .timedOut = groupWaitResu {
                    Logger.tcp.debug("Flow Write Datagrams timeout")
                    break
                }

                if let error = writeError {
                    Logger.udp.debug("Error writing datagram: \(error)") // Continue for UDP - don't break on write errors
                }
            } catch .udpRecvTimeoutOrInterrupted {
                continue // No data (timeout) - this is normal for UDP
            } catch {
                Logger.udp.debug("Socket recv error: \(error)")
            }
        }
    }

    private func sendDatagram(socket: borrowing SocketSendHalf<NetworkingErgonomics.UDP>, data: Data, to endpoint: NWEndpoint) {
        let endpointString = String(describing: endpoint)
        let port = port(from: endpoint)

        do {
            try socket.send(data: data, to: sockaddr_from_endpoint(endpoint))
        } catch .udpSendFailed(.networkUnreachable) {
            Logger.udp.debug("Network unreachable for \(endpointString):\(port)")
        } catch .udpSendFailed(.messageTooLarge) {
            Logger.udp.debug("UDP datagram too large for \(endpointString):\(port): \(data.count) bytes")
        } catch {
            Logger.udp.debug("sendto error for \(endpointString):\(port): \(error)")
        }
    }

    private func port(from endpoint: NWEndpoint) -> UInt16 {
        switch endpoint {
        case let .hostPort(_, port):
            port.rawValue
        default:
            0
        }
    }

    private func sockaddrToNWEndpoint(_ addr: inout sockaddr_in) -> NWEndpoint {
        addr.sin_zero = (0, 0, 0, 0, 0, 0, 0, 0)

        var ipString = [CChar](repeating: 0, count: Int(INET_ADDRSTRLEN))
        inet_ntop(AF_INET, &addr.sin_addr, &ipString, socklen_t(INET_ADDRSTRLEN))

        let ip = String(utf8String: ipString) ?? ""
        let port = UInt16(addr.sin_port).byteSwapped

        return NWEndpoint.hostPort(host: NWEndpoint.Host(ip), port: NWEndpoint.Port(rawValue: port)!)
    }
}

private extension NSError {
    var isPotentialQUICProbingError: Bool {
        domain == "NEAppProxyFlowErrorDomain" && code == 2
    }
}

extension UDPFlowHandler: Hashable {
    static func == (lhs: UDPFlowHandler, rhs: UDPFlowHandler) -> Bool {
        lhs === rhs
    }

    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }
}
