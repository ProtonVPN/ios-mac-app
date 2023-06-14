//
//  Created on 2023-06-14.
//
//  Copyright (c) 2023 Proton AG
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
import Foundation

// This struct is still WIP
public enum VPNConnectionStatus: Equatable {

    case disconnected

    case connected(ConnectionSpec)

    case connecting(ConnectionSpec)

    case loadingConnectionInfo(ConnectionSpec)

    case disconnecting(ConnectionSpec)

}

public extension DependencyValues {
  var watchVPNConnectionStatus: @Sendable () async -> AsyncStream<VPNConnectionStatus> {
    get { self[WatchAppStateChangesKey.self] }
    set { self[WatchAppStateChangesKey.self] = newValue }
  }
}

public enum WatchAppStateChangesKey: DependencyKey {
    public static let liveValue: @Sendable () async -> AsyncStream<VPNConnectionStatus> = {
        assert(false, "Override this dependency!")
        // Actual implementation sits in the app, to reduce the scope of thing this library depends on
        return AsyncStream<VPNConnectionStatus> { _ in }
    }
}
