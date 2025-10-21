//
//  Created on 01/10/2025 by Adam Viaud.
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

#if canImport(Darwin)
    import Darwin
    import struct Foundation.Data
    import struct Foundation.POSIXError

    public extension Socket where Protocol == TCP, State == Closed {
        /// Connects the socket to a remote endpoint.
        /// - Parameter endpoint: a `sockaddr_in` value.
        consuming func connect(to endpoint: sockaddr_in) throws(SocketError) -> Socket<TCP, Opened> {
            var endpoint: sockaddr_in = endpoint
            let result = withUnsafePointer(to: &endpoint) {
                $0.withMemoryRebound(to: sockaddr.self, capacity: 1) {
                    Darwin.connect(fd.fd, $0, socklen_t(MemoryLayout<sockaddr_in>.size))
                }
            }
            guard result == 0 else {
                throw .connectionFailed
            }
            return Socket<TCP, Opened>(fd: fd.take(), addressFamily: addressFamily)
        }

        /// Connects the socket to a remote endpoint.
        /// - Parameter endpoint: a `sockaddr_in6` value.
        consuming func connect(to endpoint: sockaddr_in6) throws(SocketError) -> Socket<TCP, Opened> {
            var endpoint: sockaddr_in6 = endpoint
            let result = withUnsafePointer(to: &endpoint) {
                $0.withMemoryRebound(to: sockaddr.self, capacity: 1) {
                    Darwin.connect(fd.fd, $0, socklen_t(MemoryLayout<sockaddr_in6>.size))
                }
            }
            guard result == 0 else {
                throw .connectionFailed
            }
            return Socket<TCP, Opened>(fd: fd.take(), addressFamily: addressFamily)
        }

        /// Connects the socket to a remote address and port.
        /// - Parameters:
        ///   - address: the IP address as a string.
        ///   - port: the port number.
        consuming func connect(to address: String, on port: some BinaryInteger) throws(SocketError) -> Socket<TCP, Opened> {
            if addressFamily == AF_INET6 {
                var addr = sockaddr_in6()
                addr.sin6_family = sa_family_t(addressFamily)
                addr.sin6_port = in_port_t(port).bigEndian
                inet_pton(addressFamily, address, &addr.sin6_addr)
                return try connect(to: addr)
            } else {
                var addr = sockaddr_in()
                addr.sin_family = sa_family_t(addressFamily)
                addr.sin_port = in_port_t(port).bigEndian
                inet_pton(addressFamily, address, &addr.sin_addr)
                return try connect(to: addr)
            }
        }
    }

    public extension Socket where Protocol == TCP, State == Opened {
        /// Receives data from the socket into the provided buffer.
        /// - Parameters:
        ///   - buffer: a `UnsafeMutablePointer` value.
        ///   - bufferSize: the size of the buffer.
        ///   - noCopy: pass `true` if you want to receive a ``Foundation.Data`` built from a shared buffer. Defaults to `false`.
        func receive(buffer: UnsafeMutablePointer<UInt8>, bufferSize: Int, noCopy: Bool = false) throws(SocketError) -> Data {
            let bytesReceived = recv(fd.fd, buffer, bufferSize, 0)

            if bytesReceived > 0 {
                if noCopy {
                    return Data(bytesNoCopy: buffer, count: bytesReceived, deallocator: .none)
                } else {
                    return Data(bytes: buffer, count: bytesReceived)
                }
            }

            if bytesReceived == 0 {
                throw .tcpRecvFailed(.closedByRemote)
            }

            let err = errno
            if err == EINTR {
                throw .tcpRecvInterrupted
            }

            throw .tcpRecvFailed(.other(.shared))
        }

        /// Sends data through the socket from an unsafe buffer.
        /// - Parameters:
        ///   - data: a `UnsafeRawBufferPointer` value.
        ///   - count: the number of bytes to send from the buffer.
        func send(data: UnsafeRawBufferPointer, count: Int) throws(SocketError) {
            var totalSent = 0
            while totalSent < count {
                let dataPtr = UnsafeRawBufferPointer(rebasing: data[totalSent...]).baseAddress
                let bytesSent = Darwin.send(fd.fd, dataPtr, count - totalSent, 0)

                if bytesSent > 0 {
                    totalSent += bytesSent
                } else if bytesSent == 0 {
                    throw .tcpSendFailed(.closedByRemote)
                } else {
                    let err = errno
                    switch err {
                    case EINTR, EAGAIN, EWOULDBLOCK:
                        continue
                    case EPIPE, ECONNRESET:
                        throw .tcpSendFailed(.closedByRemote)
                    case ENETDOWN, ENETUNREACH, EHOSTUNREACH:
                        throw .tcpSendFailed(.networkUnreachable)
                    default:
                        throw .tcpSendFailed(.other(.shared))
                    }
                }
            }
        }

        /// Sends data through the socket.
        /// - Parameter data: a ``Foundation.Data`` value.
        func send(data: Data) throws(Error) {
            do {
                let count = data.count
                try data.withUnsafeBytes { ptr in
                    try send(data: ptr, count: count)
                }
            } catch let error as SocketError {
                throw error
            } catch {
                fatalError("SocketError type not handled: \(error)")
            }
        }
    }
#endif
