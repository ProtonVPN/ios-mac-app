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

    public enum Closed {}
    public enum Opened {}

    public enum TCP {}
    public enum UDP {}

    /// Socket-related errors.
    public enum SocketError: Swift.Error {
        public enum Reason {
            case closedByRemote
            case networkUnreachable
            case messageTooLarge
            case other(errno: CInt)
        }

        case invalidSocketType
        case creationFailed
        case setSockOptFailed
        case fcntlFailed
        case interfaceNotFound
        case interfaceBindingFailed
        case connectionFailed
        case localBindFailed
        case udpSendFailed(Reason)
        case udpRecvTimeoutOrInterrupted
        case udpRecvFailed(Reason)
        case tcpSendFailed(Reason)
        case tcpRecvFailed(Reason)
        case tcpRecvInterrupted
    }

    /// Type-safe socket wrapper with protocol (TCP/UDP) and state (Closed/Opened) tracking.
    public struct Socket<Protocol, State>: ~Copyable {
        let fd: FileDescriptor
        let addressFamily: CInt

        init(fd: CInt, addressFamily: CInt) {
            self.fd = .init(fd: fd)
            self.addressFamily = addressFamily
        }
    }

    public extension Socket where Protocol == TCP, State == Closed {
        /// Creates a TCP socket.
        /// - Parameter v6: pass `true` to create an IPv6 socket. Defaults to `false`.
        static func tcp(v6: Bool = false) throws(SocketError) -> Socket<TCP, Closed> {
            let addressFamily: CInt = v6 ? AF_INET6 : AF_INET
            let rawSocketFd = socket(addressFamily, SOCK_STREAM, 0)
            guard rawSocketFd >= 0 else {
                throw .creationFailed
            }
            return Socket<TCP, Closed>(fd: rawSocketFd, addressFamily: addressFamily)
        }
    }

    public extension Socket where Protocol == UDP, State == Closed {
        /// Creates a UDP socket.
        /// - Parameter v6: pass `true` to create an IPv6 socket. Defaults to `false`.
        static func udp(v6: Bool = false) throws(SocketError) -> Socket<UDP, Closed> {
            let addressFamily: CInt = v6 ? AF_INET6 : AF_INET
            let rawSocketFd = socket(addressFamily, SOCK_DGRAM, 0)
            guard rawSocketFd >= 0 else {
                throw .creationFailed
            }
            return Socket<UDP, Closed>(fd: rawSocketFd, addressFamily: addressFamily)
        }
    }

    extension Socket: Sendable {}

    private let cIntPayloadSize: socklen_t = .init(MemoryLayout<CInt>.size)
    private let timevalPayloadSize: socklen_t = .init(MemoryLayout<timeval>.size)

    public extension Socket {
        private var fdFlags: CInt {
            fcntl(fd.fd, F_GETFL, 0)
        }

        /// Returns whether the socket is in non-blocking mode.
        var isNonBlocking: Bool {
            fdFlags & O_NONBLOCK != 0
        }

        /// Sets the socket to non-blocking or blocking mode.
        /// - Parameter nonBlocking: pass `true` to enable non-blocking mode.
        func setNonBlocking(_ nonBlocking: Bool) throws(SocketError) {
            let flags: CInt = nonBlocking ? (fdFlags | O_NONBLOCK) : (fdFlags & ~O_NONBLOCK)
            guard fcntl(fd.fd, F_SETFL, flags) == 0 else {
                throw .fcntlFailed
            }
        }

        /// Disables Nagle's algorithm when true.
        /// - Parameter noDelay: pass `true` to disable Nagle's algorithm.
        func setNoDelay(_ noDelay: Bool) throws(SocketError) {
            var noDelay: CInt = noDelay ? 1 : 0
            guard setsockopt(fd.fd, IPPROTO_TCP, TCP_NODELAY, &noDelay, cIntPayloadSize) == 0 else {
                throw .setSockOptFailed
            }
        }

        /// Enables TCP keep-alive probes.
        /// - Parameter keepAlive: pass `true` to enable keep-alive.
        func setKeepAlive(_ keepAlive: Bool) throws(SocketError) {
            var keepAlive: CInt = keepAlive ? 1 : 0
            guard setsockopt(fd.fd, SOL_SOCKET, SO_KEEPALIVE, &keepAlive, cIntPayloadSize) == 0 else {
                throw .setSockOptFailed
            }
        }

        /// Sets the send buffer size.
        /// - Parameter bufferSize: the buffer size in bytes.
        func setSendBufferSize(_ bufferSize: CInt) throws(SocketError) {
            var sendBufferSize: CInt = bufferSize
            guard setsockopt(fd.fd, SOL_SOCKET, SO_SNDBUF, &sendBufferSize, cIntPayloadSize) == 0 else {
                throw .setSockOptFailed
            }
        }

        /// Sets the receive buffer size.
        /// - Parameter bufferSize: the buffer size in bytes.
        func setRecvBufferSize(_ bufferSize: CInt) throws(SocketError) {
            var recvBufferSize: CInt = bufferSize
            guard setsockopt(fd.fd, SOL_SOCKET, SO_SNDBUF, &recvBufferSize, cIntPayloadSize) == 0 else {
                throw .setSockOptFailed
            }
        }

        /// Sets the send timeout.
        /// - Parameter timeout: a `timeval` value.
        func setSendTimeout(_ timeout: timeval) throws(SocketError) {
            var timeout = timeout
            guard setsockopt(fd.fd, SOL_SOCKET, SO_SNDTIMEO, &timeout, timevalPayloadSize) == 0 else {
                throw .setSockOptFailed
            }
        }

        /// Sets the receive timeout.
        /// - Parameter timeout: a `timeval` value.
        func setRecvTimeout(_ timeout: timeval) throws(SocketError) {
            var timeout = timeout
            guard setsockopt(fd.fd, SOL_SOCKET, SO_RCVTIMEO, &timeout, timevalPayloadSize) == 0 else {
                throw .setSockOptFailed
            }
        }

        /// Allows reuse of local addresses.
        /// - Parameter reuseAddr: pass `true` to enable address reuse.
        func setReuseAddr(_ reuseAddr: Bool) throws(SocketError) {
            var reuseAddr: CInt = 1
            guard setsockopt(fd.fd, SOL_SOCKET, SO_REUSEADDR, &reuseAddr, cIntPayloadSize) == 0 else {
                throw .setSockOptFailed
            }
        }

        /// Allows multiple sockets to bind to the same port.
        /// - Parameter reusePort: pass `true` to enable port reuse.
        func setReusePort(_ reusePort: Bool) throws(SocketError) {
            var reusePort: CInt = 1
            guard setsockopt(fd.fd, SOL_SOCKET, SO_REUSEPORT, &reusePort, cIntPayloadSize) == 0 else {
                throw .setSockOptFailed
            }
        }

        /// Prevents SIGPIPE signal on write errors.
        /// - Parameter noSigPipe: pass `true` to prevent SIGPIPE.
        func setNoSigPipe(_ noSigPipe: Bool) throws(SocketError) {
            var noSigPipe: CInt = noSigPipe ? 1 : 0
            guard setsockopt(fd.fd, SOL_SOCKET, SO_NOSIGPIPE, &noSigPipe, cIntPayloadSize) == 0 else {
                throw .setSockOptFailed
            }
        }
    }

    public extension Socket where State == Closed {
        /// Binds the socket to a specific network interface by index.
        /// - Parameter ifIndex: the network interface index.
        func bindToInterface(ifIndex: CInt) throws(SocketError) {
            var ifIndex: CInt = ifIndex
            guard setsockopt(fd.fd, IPPROTO_IP, IP_BOUND_IF, &ifIndex, cIntPayloadSize) == 0 else {
                throw .interfaceBindingFailed
            }
        }

        /// Binds the socket to a specific network interface by name.
        /// - Parameter name: the network interface name.
        func bindToInterface(name: String) throws(SocketError) {
            let interfaceIndex = if_nametoindex(name)
            guard interfaceIndex > 0 else {
                throw .interfaceNotFound
            }
            try bindToInterface(ifIndex: CInt(interfaceIndex))
        }
    }

    public extension Socket where State == Opened {
        /// Shuts down both read and write operations and consumes the socket.
        consuming func shutdown() {
            Darwin.shutdown(fd.fd, SHUT_RDWR)
        }

        /// Shuts down the read side of the socket.
        func shutdownRead() {
            Darwin.shutdown(fd.fd, SHUT_RD)
        }

        /// Shuts down the write side of the socket.
        func shutdownWrite() {
            Darwin.shutdown(fd.fd, SHUT_WR)
        }
    }
#endif
