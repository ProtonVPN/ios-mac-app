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
import Dependencies

private var appStateManager: AppStateManager! = Container.sharedContainer.makeAppStateManager()

extension WatchAppStateChangesKey {

    public static let watchVPNConnectionStatusChanges: @Sendable () async -> AsyncStream<VPNConnectionStatus> = {
        return NotificationCenter.default
            .notifications(named: .AppStateManager.displayStateChange)
            .map({
                let appStageManager = Container.sharedContainer.makeAppStateManager()
                 return ($0.object as! AppDisplayState).vpnConnectionStatus(appStageManager.activeConnection())
              })
            .eraseToStream()
    }

}

// MARK: - AppDisplayState -> VPNConnectionStatus

extension AppDisplayState {

    func vpnConnectionStatus(_ connectionConfiguration: ConnectionConfiguration?) -> VPNConnectionStatus {
        let fakeSpecs = ConnectionSpec(location: .fastest, features: [])
        switch self {
        case .connected:
            return .connected(fakeSpecs, connectionConfiguration?.vpnConnectionActual)

        case .connecting:
            return .connecting(fakeSpecs, connectionConfiguration?.vpnConnectionActual)

        case .loadingConnectionInfo:
            return .loadingConnectionInfo(fakeSpecs, connectionConfiguration?.vpnConnectionActual)

        case .disconnecting:
            return .disconnecting(fakeSpecs, connectionConfiguration?.vpnConnectionActual)

        case .disconnected:
            return .disconnected
        }
    }
}

extension ConnectionConfiguration {
    var vpnConnectionActual: VPNConnectionActual {
        VPNConnectionActual(
            serverModelId: self.server.id,
            serverIPId: self.serverIp.id,
            vpnProtocol: self.vpnProtocol,
            natType: self.natType,
            safeMode: self.safeMode,
            feature: self.server.feature,
            city: self.server.city
        )
    }
}
