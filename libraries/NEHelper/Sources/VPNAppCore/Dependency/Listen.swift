//
//  Created on 03/12/2024.
//
//  Copyright (c) 2024 Proton AG
//
//  ProtonVPN is free software: you can redistribute it and/or modify
//  it under the terms of the GNU General Public License as published by
//  the Free Software Foundation, either version 3 of the License, or
//  (at your option) any later version.
//
//  ProtonVPN is distributed in the hope that it will be useful,
//  but WITHOUT ANY WARRANTY; without even the implied warranty of
//  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
//  GNU General Public License for more details.
//
//  You should have received a copy of the GNU General Public License
//  along with ProtonVPN.  If not, see <https://www.gnu.org/licenses/>.

import Dependencies

extension DependencyValues {
    /// ATM it's neither async nor throws, but the plan is to return only after connection is made and also to throw exceptions
    /// so user can be presented with an error from UI, and not from the depths of VPN connection related code.
    public var listenVPNStatus: @Sendable () -> AsyncStream<VPNConnectionStatus> {
        get { self[ListenVPNStatusKey.self] }
        set { self[ListenVPNStatusKey.self] = newValue }
    }
}

public enum ListenVPNStatusKey: TestDependencyKey {
    public static let testValue: @Sendable () -> AsyncStream<VPNConnectionStatus> = {
        AsyncStream<VPNConnectionStatus> { $0.finish() }
    }
}
