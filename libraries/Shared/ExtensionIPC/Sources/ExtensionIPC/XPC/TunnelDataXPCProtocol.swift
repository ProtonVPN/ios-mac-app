//
//  Created on 23/06/2026.
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

#if os(macOS)
    import Foundation
    import IOSurface

    @objc
    public protocol TunnelDataXPCProtocol {
        /// Returns the shared `IOSurface` backing the tunnel-data region on macOS, or `nil` if it isn't available yet.
        func fetchTunnelDataSurface(_ reply: @escaping (IOSurface?) -> Void)
    }
#endif
