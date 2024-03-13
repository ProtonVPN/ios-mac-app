//
//  Created on 2023-07-05.
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

import Combine

import Dependencies

import Domain

extension DependencyValues {
    var vpnConnectionStatus: @Sendable () async -> VPNConnectionStatus {
        get { self[VPNConnectionStatusKey.self] }
        set { self[VPNConnectionStatusKey.self] = newValue }
    }
}

public enum VPNConnectionStatusKey: DependencyKey {
    public static let liveValue: @Sendable () async -> VPNConnectionStatus = {
        log.assertionFailure("Override this dependency!")
        return .disconnected
    }
}

public enum WatchAppStateChangesKey: DependencyKey {
    public static let liveValue: @Sendable () async -> AsyncStream<VPNConnectionStatus> = {
        log.assertionFailure("Override this dependency!")
        // Actual implementation sits in the app, to reduce the scope of thing this library depends on
        return AsyncStream<VPNConnectionStatus> { _ in }
    }
}
