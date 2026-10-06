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

#if os(macOS) || os(iOS)
    import Ergonomics
    import Foundation
    @testable import NetworkingErgonomics
    import Testing

    @Suite("Socket interface binding")
    struct SocketInterfaceBindingTests {
        /// The loopback interface, which every machine that runs these tests has.
        private static let loopback = if_nametoindex("lo0")

        /// IPv4 and IPv6 sockets take different options, and the system refuses the wrong one.
        @Test(arguments: [IPVersion.v4, .v6])
        func bindsASocketItCreatedToAnInterface(family: IPVersion) throws {
            let socket = try Socket.udp(v6: family == .v6)

            try socket.bindToInterface(index: Self.loopback)
            let bound = boundInterface(of: socket.fd.fd, family)

            #expect(bound == Self.loopback)
        }

        @Test(arguments: [IPVersion.v4, .v6])
        func bindsABorrowedSocketToAnInterface(family: IPVersion) throws {
            let foreign = ForeignSocket(family: family.addressFamily)

            try Socket.borrowing(foreign.descriptor) { socket throws(SocketError) in
                try socket.bindToInterface(index: Self.loopback)
            }
            let bound = boundInterface(of: foreign.descriptor, family)

            #expect(bound == Self.loopback)
        }

        /// Whoever lent the descriptor goes on to use it, whether or not the closure succeeded.
        @Test
        func leavesABorrowedDescriptorOpen() throws {
            let foreign = ForeignSocket(family: AF_INET)
            let descriptor = foreign.descriptor

            try Socket.borrowing(descriptor) { _ in }
            let isOpenAfterSuccess = foreign.isOpen

            #expect(throws: SocketError.self) {
                try Socket.borrowing(descriptor) { socket throws(SocketError) in
                    try socket.bindToInterface(index: UInt32(Int32.max))
                }
            }
            let isOpenAfterFailure = foreign.isOpen

            #expect(isOpenAfterSuccess)
            #expect(isOpenAfterFailure)
        }

        /// A Unix domain socket has no IP version, so there is no option to bind it with.
        @Test
        func refusesToBorrowASocketThatIsNotAnIPSocket() {
            let foreign = ForeignSocket(family: AF_UNIX)
            let descriptor = foreign.descriptor

            #expect(throws: SocketError.self) {
                try Socket.borrowing(descriptor) { _ in }
            }
            let isOpen = foreign.isOpen

            #expect(isOpen)
        }
    }

    /// A socket opened outside `Socket`, the way another library opens one before lending it. It closes itself.
    private struct ForeignSocket: ~Copyable {
        let descriptor: CInt
        /// A second descriptor for the same socket. The code under test never sees it, so it stays open.
        private let witness: CInt

        init(family: CInt) {
            self.descriptor = socket(family, SOCK_STREAM, 0)
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
            var read: CInt = 0
            var length = socklen_t(MemoryLayout<CInt>.size)
            setsockopt(witness, SOL_SOCKET, SO_RCVLOWAT, &written, length)
            getsockopt(descriptor, SOL_SOCKET, SO_RCVLOWAT, &read, &length)
            return read == written
        }
    }

    /// The index of the interface the system reports the socket as bound to. Zero means it is not bound, and nil
    /// means the system could not say.
    private func boundInterface(of descriptor: CInt, _ family: IPVersion) -> UInt32? {
        let (level, name) = switch family {
        case .v4: (IPPROTO_IP, IP_BOUND_IF)
        case .v6: (IPPROTO_IPV6, IPV6_BOUND_IF)
        }
        var index: UInt32 = 0
        var length = socklen_t(MemoryLayout<UInt32>.size)
        return getsockopt(descriptor, level, name, &index, &length) == 0 ? index : nil
    }
#endif
