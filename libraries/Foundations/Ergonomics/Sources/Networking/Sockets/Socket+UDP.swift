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

#if os(macOS) || os(iOS)
    import Darwin
    import struct Foundation.Data

    public extension Socket where Protocol == UDP {
        /// Returns the local endpoint the socket is bound to.
        var localEndpoint: sockaddr_in {
            get throws(SocketError) {
                var localAddr = sockaddr_in()
                var addrLen = socklen_t(MemoryLayout<sockaddr_in>.size)
                getsockname(
                    fd.fd,
                    withUnsafeMutablePointer(to: &localAddr) {
                        $0.withMemoryRebound(to: sockaddr.self, capacity: 1) { $0 }
                    },
                    &addrLen
                )
                return localAddr
            }
        }
    }

    public extension Socket where Protocol == UDP, State == Closed {
        /// Binds the socket to a local port (0 for auto-assign).
        /// - Parameter port: the port you want to bind the socket to. Defaults to `.zero` to let the OS choose.
        consuming func bindLocally(to port: UInt16 = .zero) throws(SocketError) -> Socket<UDP, Opened> {
            var addr = sockaddr_in()
            addr.sin_family = sa_family_t(AF_INET)
            addr.sin_port = in_port_t(port).bigEndian
            let bindResult = withUnsafePointer(to: &addr) {
                $0.withMemoryRebound(to: sockaddr.self, capacity: 1) {
                    bind(fd.fd, $0, socklen_t(MemoryLayout<sockaddr_in>.size))
                }
            }
            guard bindResult == 0 else {
                throw .localBindFailed
            }
            return Socket<UDP, Opened>(fd: fd.take(), addressFamily: addressFamily)
        }
    }

    public extension Socket where Protocol == UDP, State == Opened {
        /// Sends data to a specific address.
        ///
        /// Throws a ``SocketError.udpSendFailed`` if an error occurs.
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

        /// Receives data from any sender, populating the sender's address.
        /// - Parameters:
        ///   - buffer: a `UnsafeMutablePointer` value.
        ///   - bufferSize: the size of the buffer.
        ///   - senderAddr: an inout `sockaddr_in` value that will contain the sender's address.
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
