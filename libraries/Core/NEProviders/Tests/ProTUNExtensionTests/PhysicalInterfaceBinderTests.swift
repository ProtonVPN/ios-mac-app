//
//  Created on 05/10/2026.
//
//  Copyright (c) 2026 Proton AG
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

import Darwin
import Network
import NetworkingErgonomics
@testable import ProTUNExtension
import Testing

@Suite("Physical interface binder")
struct PhysicalInterfaceBinderTests {
    @Test
    func bindsASocketToThePathsPhysicalInterface() {
        let socket = TestSocket()
        let binder = PhysicalInterfaceBinder(currentPath: { .loopback })

        let isProtected = binder.protectSocket(socketFd: socket.descriptor)
        let boundInterface = socket.boundInterface

        #expect(isProtected)
        #expect(boundInterface == NetworkPath.loopbackIndex)
    }

    /// ProTUN must not connect this socket, because the system would route it into the tunnel.
    @Test
    func refusesASocketWhileThePathHasNoPhysicalInterface() {
        let socket = TestSocket()
        let binder = PhysicalInterfaceBinder(currentPath: { .initial })

        let isProtected = binder.protectSocket(socketFd: socket.descriptor)
        let boundInterface = socket.boundInterface

        #expect(!isProtected)
        #expect(boundInterface == 0)
    }

    @Test
    func refusesASocketWhenThePathsInterfaceIsGone() {
        let socket = TestSocket()
        let binder = PhysicalInterfaceBinder(currentPath: { .removedInterface })

        let isProtected = binder.protectSocket(socketFd: socket.descriptor)
        let boundInterface = socket.boundInterface

        #expect(!isProtected)
        #expect(boundInterface == 0)
    }

    /// The system reports index 0 for an interface it no longer has. Binding to 0 would succeed and leave the socket
    /// unbound, so the binder must refuse instead.
    @Test
    func refusesASocketWhenThePathsInterfaceHasNoIndex() {
        let socket = TestSocket()
        let binder = PhysicalInterfaceBinder(currentPath: { .indexlessInterface })

        let isProtected = binder.protectSocket(socketFd: socket.descriptor)
        let boundInterface = socket.boundInterface

        #expect(!isProtected)
        #expect(boundInterface == 0)
    }

    /// ProTUN connects the socket after the binder returns, so the binder must leave the descriptor open.
    @Test(arguments: [NetworkPath.loopback, .removedInterface, .indexlessInterface])
    func leavesProTUNsSocketOpen(path: NetworkPath) {
        let socket = TestSocket()
        let binder = PhysicalInterfaceBinder(currentPath: { path })

        _ = binder.protectSocket(socketFd: socket.descriptor)
        let isOpen = socket.isOpen

        #expect(isOpen)
    }
}

/// An IPv4 UDP socket in the state ProTUN hands one over in, neither bound nor connected. It closes itself.
private struct TestSocket: ~Copyable {
    let descriptor: Int32
    /// A second descriptor for the same socket. The binder never sees it, so it stays open.
    private let witness: Int32

    init() {
        self.descriptor = socket(AF_INET, SOCK_DGRAM, 0)
        self.witness = dup(descriptor)
    }

    deinit {
        close(descriptor)
        close(witness)
    }

    /// Whether `descriptor` still refers to this socket. The system gives a closed descriptor's number to the next
    /// socket a test running in parallel opens, so an open number proves nothing. This changes a setting through
    /// `witness` and reads it back through `descriptor`. The two only agree while both refer to the same socket.
    var isOpen: Bool {
        // No other open socket has this value, because no other open descriptor has the witness's number.
        var written = 1000 + witness
        var read: Int32 = 0
        var length = socklen_t(MemoryLayout<Int32>.size)
        setsockopt(witness, SOL_SOCKET, SO_RCVLOWAT, &written, length)
        getsockopt(descriptor, SOL_SOCKET, SO_RCVLOWAT, &read, &length)
        return read == written
    }

    /// The index of the interface the system reports this socket as bound to. Zero means it is not bound, and nil
    /// means the system could not say.
    var boundInterface: UInt32? {
        var index: UInt32 = 0
        var length = socklen_t(MemoryLayout<UInt32>.size)
        let status = getsockopt(descriptor, IPPROTO_IP, IP_BOUND_IF, &index, &length)
        return status == 0 ? index : nil
    }
}

private extension NetworkPath {
    /// The loopback interface, which every machine that runs these tests has.
    static let loopbackIndex = if_nametoindex("lo0")

    static let loopback = NetworkPath(
        status: .satisfied,
        interfaceName: "lo0",
        interfaceIndex: loopbackIndex,
        interfaceType: .loopback,
        gateways: [],
        supportsIPv4: true,
        supportsIPv6: true
    )

    /// A usable path whose interface the system no longer has.
    static let removedInterface = NetworkPath(
        status: .satisfied,
        interfaceName: "en9",
        interfaceIndex: UInt32(Int32.max),
        interfaceType: .wifi,
        gateways: [],
        supportsIPv4: true,
        supportsIPv6: false
    )

    /// A usable path whose interface the system reports with index 0, as it does for one it no longer has.
    static let indexlessInterface = NetworkPath(
        status: .satisfied,
        interfaceName: "pdp_ip0",
        interfaceIndex: 0,
        interfaceType: .cellular,
        gateways: [],
        supportsIPv4: true,
        supportsIPv6: false
    )
}
