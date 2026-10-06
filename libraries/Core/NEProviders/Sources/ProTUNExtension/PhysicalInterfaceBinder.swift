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

import NetworkingErgonomics
import os.log
import protun

/// Keeps the sockets ProTUN opens toward a VPN server out of the tunnel, by binding each one to the device's physical
/// interface. This is the Apple counterpart of `VpnService.protect` on Android.
///
/// The tunnel's default route covers every destination. An unbound socket follows that route into the tunnel whenever
/// the system has no other route to the server. A bound socket can only leave the device through its interface.
final class PhysicalInterfaceBinder: SocketProtector {
    /// Returns the path the system reports right now. ProTUN calls the binder from its connection thread, so any
    /// thread must be able to call this.
    private let currentPath: @Sendable () -> NetworkPath

    init(currentPath: @escaping @Sendable () -> NetworkPath) {
        self.currentPath = currentPath
    }

    /// ProTUN calls this from its connection thread before it connects `socketFd`. ProTUN does not connect a socket
    /// this returns false for. It treats the network as unreachable instead, and tries again later.
    func protectSocket(socketFd: Int32) -> Bool {
        let path = currentPath()
        do {
            try bind(socketFd, to: path)
            return true
        } catch {
            Logger.adapter.error(
                "Could not bind socket \(socketFd) on path \(path, privacy: .public): \(error, privacy: .public)"
            )
            return false
        }
    }

    /// Binds ProTUN's socket to the physical interface of `path`. ProTUN opened the socket and closes it, so this only
    /// borrows it.
    private func bind(_ socketFd: Int32, to path: NetworkPath) throws(SocketError) {
        guard let interfaceIndex = path.vpnSocketInterfaceIndex else { throw .interfaceNotFound }
        try Socket.borrowing(socketFd) { socket throws(SocketError) in
            try socket.bindToInterface(index: interfaceIndex)
        }
    }
}

extension NetworkPath {
    /// The physical interface ProTUN's sockets toward a VPN server are bound to, or nil while this path is not usable
    /// or has no physical interface.
    ///
    /// ProTUN is only told that the network is available while this is not nil, because a socket it opens without a
    /// physical interface would be routed into the tunnel.
    var vpnSocketInterfaceIndex: UInt32? {
        isUsable ? interfaceIndex : nil
    }
}
