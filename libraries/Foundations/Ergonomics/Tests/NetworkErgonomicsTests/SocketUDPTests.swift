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

    /// Helper to create a sockaddr_in for localhost with the given port.
    private func localhostAddr(port: UInt16) -> sockaddr_in {
        var addr = sockaddr_in()
        addr.sin_family = sa_family_t(AF_INET)
        addr.sin_port = port.bigEndian
        addr.sin_addr.s_addr = inet_addr("127.0.0.1")
        return addr
    }

    struct SocketUDPTests {
        @Test("Socket creation (IPv4)")
        func socketCreation() throws {
            let socket = try Socket.udp()
            #expect(socket.addressFamily == AF_INET)
        }

        @Test("Socket creation (IPv6)")
        func socketCreationV6() throws {
            let socket = try Socket.udp(v6: true)
            #expect(socket.addressFamily == AF_INET6)
        }

        @Test("Socket binds to auto-assigned port")
        func socketBindAutoPort() throws {
            let socket = try Socket.udp()
            let boundSocket = try socket.bindLocally(to: 0)

            let localEndpoint = try boundSocket.localEndpoint
            let assignedPort = UInt16(bigEndian: localEndpoint.sin_port)

            #expect(assignedPort > 0)
        }

        @Test("Socket binds to specific port")
        func socketBindSpecificPort() throws {
            let desiredPort: UInt16 = 54321

            let socket = try Socket.udp()
            let boundSocket = try socket.bindLocally(to: desiredPort)

            let localEndpoint = try boundSocket.localEndpoint
            let actualPort = UInt16(bigEndian: localEndpoint.sin_port)

            #expect(actualPort == desiredPort)
        }

        @Test("Sends and receives data between two sockets")
        func socketsSendReceive() throws {
            let sender = try Socket.udp()
            let boundSender = try sender.bindLocally(to: 0)

            let receiver = try Socket.udp()
            let boundReceiver = try receiver.bindLocally(to: 0)

            let receiverEndpoint = try boundReceiver.localEndpoint
            let receiverPort = UInt16(bigEndian: receiverEndpoint.sin_port)

            let testMessage = "Hello, UDP!"
            let testData = testMessage.data(using: .utf8)!
            let receiverAddr = localhostAddr(port: receiverPort)

            try boundSender.send(data: testData, to: receiverAddr)

            var buffer = UnsafeMutablePointer<UInt8>.allocate(capacity: 4096)
            defer { buffer.deallocate() }

            var senderAddr = sockaddr_in()
            let receivedData = try boundReceiver.receive(
                buffer: &buffer,
                bufferSize: 4096,
                senderAddr: &senderAddr
            )

            let receivedMessage = String(data: receivedData, encoding: .utf8)
            #expect(receivedMessage == testMessage)

            // Verify sender address is correct
            let senderPort = UInt16(bigEndian: senderAddr.sin_port)
            let senderLocalEndpoint = try boundSender.localEndpoint
            let expectedSenderPort = UInt16(bigEndian: senderLocalEndpoint.sin_port)
            #expect(senderPort == expectedSenderPort)
        }

        @Test("Socket configuration methods")
        func socketConfiguration() throws {
            let socket = try Socket.udp()

            // Test non-blocking mode
            let isNonBlockingBefore = socket.isNonBlocking
            #expect(!isNonBlockingBefore)
            try socket.setNonBlocking(true)
            let isNonBlockingAfterFirstSet = socket.isNonBlocking
            #expect(isNonBlockingAfterFirstSet)
            try socket.setNonBlocking(false)
            let isNonBlockingAfterSecondSet = socket.isNonBlocking
            #expect(!isNonBlockingAfterSecondSet)

            // Test other configuration methods
            try socket.setSendBufferSize(8192)
            try socket.setRecvBufferSize(8192)
            try socket.setReuseAddr(true)
            try socket.setReusePort(true)

            let timeout = timeval(tv_sec: 5, tv_usec: 0)
            try socket.setSendTimeout(timeout)
            try socket.setRecvTimeout(timeout)
        }
    }
#endif
