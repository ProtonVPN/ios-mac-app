//
//  Created on 21/08/2026.
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
    import Darwin

    /// Reads the utun interface name (for example "utun4") off the tunnel's control-socket descriptor. Returns nil when
    /// the descriptor is not a utun control socket.
    public func interfaceName(ofTunnelDescriptor descriptor: CInt) -> String? {
        // SYSPROTO_CONTROL comes from <sys/kern_control.h> and UTUN_OPT_IFNAME from <net/if_utun.h>.
        let SYSPROTO_CONTROL: Int32 = 2
        let UTUN_OPT_IFNAME: Int32 = 2

        var buffer = [CChar](repeating: 0, count: Int(IFNAMSIZ))
        var length = socklen_t(buffer.count)
        guard getsockopt(descriptor, SYSPROTO_CONTROL, UTUN_OPT_IFNAME, &buffer, &length) == 0 else {
            return nil
        }
        return String(cString: buffer)
    }

    /// The kernel's index for the utun interface behind the tunnel's control-socket descriptor. Returns nil when the
    /// descriptor is not a utun control socket or the kernel has no index for the interface.
    public func interfaceIndex(ofTunnelDescriptor descriptor: CInt) -> UInt32? {
        guard let name = interfaceName(ofTunnelDescriptor: descriptor) else { return nil }
        let index = if_nametoindex(name)
        return index == 0 ? nil : index
    }
#endif
