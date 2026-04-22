//
//  Created on 07/01/2026 by adam.
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

#if canImport(Darwin)
    import NetworkExtension

    public extension FileDescriptor {
        static func tunFileDescriptor(for provider: NEPacketTunnelProvider) -> Self? {
            for fd: CInt in 0 ... 1024 {
                var buf = [CChar](repeating: 0, count: Int(IFNAMSIZ))
                var len = socklen_t(buf.count)

                if getsockopt(fd, 2 /* IGMP */, 2, &buf, &len) == 0 {
                    let cString = String(cString: &buf)
                    if cString.hasPrefix("utun") {
                        return .init(fd: fd)
                    }
                }
            }
            // Fallback...
            let key = "socket.fileDescriptor"
            let selector = NSSelectorFromString(key)
            let packetFlow = provider.packetFlow
            if packetFlow.responds(to: selector) {
                let fd = packetFlow.value(forKey: key) as? CInt
                return fd.flatMap { .init(fd: $0) }
            }
            return nil
        }
    }
#endif
