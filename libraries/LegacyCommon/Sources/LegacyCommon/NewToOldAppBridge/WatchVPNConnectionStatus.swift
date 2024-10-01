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

import Dependencies
import ComposableArchitecture
import ConcurrencyExtras

import Domain
import VPNAppCore
import PMLogger

private let appStateManager: AppStateManager = Container.sharedContainer.makeAppStateManager()

extension VPNConnectionStatusPublisherKey {

    @available(macOS 12, *)
    public static let watchVPNConnectionStatusChanges: () -> AsyncStream<VPNConnectionStatus> = {
        return NotificationCenter.default
            .notifications(named: .AppStateManager.displayStateChange)
            .map {
                let appStageManager = Container.sharedContainer.makeAppStateManager()

                // todo: when VPN connection will be refactored, please try saving lastConnectionIntent
                // inside NETunnelProviderProtocol.providerConfiguration for WG and OpenVPN.
                let propertyManager = Container.sharedContainer.makePropertiesManager()

                return ($0.object as! AppDisplayState).vpnConnectionStatus(appStageManager.activeConnection(), intent: propertyManager.lastConnectionIntent)
            }
            .eraseToStream()
    }

}

// MARK: - AppDisplayState -> VPNConnectionStatus

extension AppDisplayState {

    func vpnConnectionStatus(_ connectionConfiguration: ConnectionConfiguration?, intent: ConnectionSpec) -> VPNConnectionStatus {
        switch self {
        case .connected:
            return .connected(intent, connectionConfiguration?.vpnConnectionActual)

        case .connecting:
            return .connecting(intent, connectionConfiguration?.vpnConnectionActual)

        case .loadingConnectionInfo:
            return .loadingConnectionInfo(intent, connectionConfiguration?.vpnConnectionActual)

        case .disconnecting:
            return .disconnecting(intent, connectionConfiguration?.vpnConnectionActual)

        case .disconnected:
            return .disconnected
        }
    }
}

extension ConnectionConfiguration {
    var vpnConnectionActual: VPNConnectionActual {
        return VPNConnectionActual(
            serverModelId: self.server.id,
            serverExitIP: self.serverIp.exitIp,
            vpnProtocol: self.vpnProtocol,
            natType: self.natType,
            safeMode: self.safeMode,
            feature: self.server.feature,
            serverName: self.server.name,
            country: self.server.exitCountryCode,
            city: self.server.city,
            coordinates: .init(latitude: self.server.location.lat,
                               longitude: self.server.location.long)
        )
    }
}
