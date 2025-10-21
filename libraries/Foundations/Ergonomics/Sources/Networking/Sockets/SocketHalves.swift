//
//  Created on 18/10/2025 by Adam Viaud.
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

    /// Independently-managed send and receive halves of a socket.
    public struct SocketHalves<Protocol>: ~Copyable {
        /// The send half.
        public let send: SocketSendHalf<Protocol>
        /// The receive half.
        public let recv: SocketRecvHalf<Protocol>
    }

    // MARK: - Socket Send Half

    /// Write-only half of a socket that shuts down write on deinit.
    public struct SocketSendHalf<Protocol>: ~Copyable {
        let fd: FileDescriptor

        deinit {
            shutdown(fd.fd, SHUT_WR)
        }
    }

    extension SocketSendHalf: Sendable {}

    public extension SocketSendHalf where Protocol == TCP {
        /// Sends data through the TCP socket from an unsafe buffer.
        ///
        /// Throws ``SocketError.tcpSendFailed`` if an error occurs.
        /// - Parameters:
        ///   - data: a ``UnsafeRawBufferPointer`` value.
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

        /// Sends data through the TCP socket.
        /// - Parameter data: a ``Foundation.Data`` value.
        func send(data: Data) throws(SocketError) {
            do {
                let count = data.count
                try data.withUnsafeBytes { ptr in
                    try send(data: ptr, count: count)
                }
            } catch let error as SocketError {
                throw error
            } catch {
                fatalError() // this shouldn't happen, it's just a limitation of the Swift Compiler
            }
        }
    }

    public extension SocketSendHalf where Protocol == UDP {
        /// Sends data to a specific address via UDP.
        ///
        /// Throws ``SocketError.udpSendFailed`` if an error occurs.
        /// - Parameters:
        ///   - data: a ``Foundation.Data`` value.
        ///   - address: a ``sockaddr_in`` value.
        func send(data: Data, to address: sockaddr_in) throws(SocketError) {
            var address: sockaddr_in = address
            let result = data.withUnsafeBytes { bytes in
                withUnsafePointer(to: &address) {
                    $0.withMemoryRebound(to: sockaddr.self, capacity: 1) {
                        sendto(
                            fd.fd,
                            bytes.bindMemory(to: UInt8.self).baseAddress,
                            data.count,
                            0,
                            $0,
                            socklen_t(MemoryLayout<sockaddr_in>.size)
                        )
                    }
                }
            }
            if result < 0 {
                let err = errno
                switch err {
                case ENETUNREACH, EHOSTUNREACH:
                    throw .udpSendFailed(.networkUnreachable)
                case EMSGSIZE:
                    throw .udpSendFailed(.messageTooLarge)
                default:
                    throw .udpSendFailed(.other(.shared))
                }
            }
        }
    }

    // MARK: - Socket Receive Half

    /// Read-only half of a socket that shuts down read on deinit.
    public struct SocketRecvHalf<Protocol>: ~Copyable {
        let fd: FileDescriptor

        deinit {
            shutdown(fd.fd, SHUT_RD)
        }
    }

    extension SocketRecvHalf: Sendable {}

    public extension SocketRecvHalf where Protocol == TCP {
        /// Receives data from the TCP socket into the provided buffer.
        /// - Parameters:
        ///   - buffer: a ``UnsafeMutablePointer`` value.
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
    }

    public extension SocketRecvHalf where Protocol == UDP {
        /// Receives data from any sender via UDP, populating the sender's address.
        /// - Parameters:
        ///   - buffer: a ``UnsafeMutablePointer`` value.
        ///   - bufferSize: the size of the buffer.
        ///   - senderAddr: an inout ``sockaddr_in`` value that will contain the sender's address.
        ///   - noCopy: pass `true` if you want to receive a ``Foundation.Data`` built from a shared buffer. Defaults to `false`.
        func receive(
            buffer: inout UnsafeMutablePointer<UInt8>,
            bufferSize: Int,
            senderAddr: inout sockaddr_in,
            noCopy: Bool = false
        ) throws(SocketError) -> Data {
            var senderAddrLen = socklen_t(MemoryLayout<sockaddr_in>.size)

            let bytesReceived = withUnsafeMutablePointer(to: &senderAddr) {
                $0.withMemoryRebound(to: sockaddr.self, capacity: 1) {
                    recvfrom(fd.fd, buffer, bufferSize, 0, $0, &senderAddrLen)
                }
            }

            if bytesReceived > 0 {
                if noCopy {
                    return Data(bytesNoCopy: buffer, count: bytesReceived, deallocator: .none)
                } else {
                    return Data(bytes: buffer, count: bytesReceived)
                }
            }

            if bytesReceived == 0 {
                throw .udpRecvTimeoutOrInterrupted
            }

            let err = errno
            if err == EAGAIN || err == EWOULDBLOCK || err == EINTR {
                throw .udpRecvTimeoutOrInterrupted
            }

            throw .udpRecvFailed(.other(.shared))
        }
    }
#endif
