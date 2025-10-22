//
//  Created on 20/10/2025 by Adam Viaud.
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
    import Foundation
    @testable import NetworkingErgonomics
    import Testing

    struct SocketTCPTests {
        @Test("Socket creation (IPv4)")
        func socketCreation() throws {
            let socket = try Socket.tcp()
            #expect(socket.addressFamily == AF_INET)
        }

        @Test("Socket creation (IPv6)")
        func socketCreationV6() throws {
            let socket = try Socket.tcp(v6: true)
            #expect(socket.addressFamily == AF_INET6)
        }

        @Test("TCP socket configuration methods")
        func socketConfiguration() throws {
            let socket = try Socket.tcp()

            let isNonBlockingBefore = socket.isNonBlocking
            #expect(!isNonBlockingBefore)
            try socket.setNonBlocking(true)
            let isNonBlockingAfterFirstSet = socket.isNonBlocking
            #expect(isNonBlockingAfterFirstSet)
            try socket.setNonBlocking(false)
            let isNonBlockingAfterSecondSet = socket.isNonBlocking
            #expect(!isNonBlockingAfterSecondSet)

            try socket.setNoDelay(true)
            try socket.setKeepAlive(true)
            try socket.setSendBufferSize(8192)
            try socket.setRecvBufferSize(8192)
            try socket.setReuseAddr(true)
            try socket.setReusePort(true)
            try socket.setNoSigPipe(true)

            let timeout = timeval(tv_sec: 5, tv_usec: 0)
            try socket.setSendTimeout(timeout)
            try socket.setRecvTimeout(timeout)
        }

        @Test("Socket connection failure to invalid address")
        func socketConnectionFailure() throws {
            #expect(throws: SocketError.self) {
                let socket = try Socket.tcp()
                _ = try socket.connect(to: "127.0.0.1", on: 1) // Port 1, likely not listening
            }
        }
    }
#endif
