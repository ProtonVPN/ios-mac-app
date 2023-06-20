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

import Foundation
import ComposableArchitecture
import VPNAppCore
import PMLogger

private var appStateManager: AppStateManager! = Container.sharedContainer.makeAppStateManager()

extension WatchAppStateChangesKey {

    public static let watchVPNConnectionStatusChanges: @Sendable () async -> AsyncStream<VPNConnectionStatus> = {
        return NotificationCenter.default
            .notifications(named: .AppStateManager.displayStateChange)
            .map({
                ($0.object as! AppDisplayState).vpnConnectionStatus
            })
            .eraseToStream()
    }

}

// MARK: - AppDisplayState -> VPNConnectionStatus

extension AppDisplayState {

    var vpnConnectionStatus: VPNConnectionStatus {
        let fakeSpecs = ConnectionSpec(location: .fastest, features: [])
        switch self {
        case .connected:
            return .connected(fakeSpecs)

        case .connecting:
            return .connecting(fakeSpecs)

        case .loadingConnectionInfo:
            return .loadingConnectionInfo(fakeSpecs)

        case .disconnecting:
            return .disconnecting(fakeSpecs)

        case .disconnected:
            return .disconnected
        }
    }
}
