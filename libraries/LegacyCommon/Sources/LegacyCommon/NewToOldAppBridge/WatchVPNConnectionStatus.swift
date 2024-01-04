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
import Combine

import ComposableArchitecture
import Dependencies

import Domain
import VPNAppCore
import PMLogger

private var appStateManager: AppStateManager! = Container.sharedContainer.makeAppStateManager()

extension VPNConnectionStatusPublisherKey {

    public static let watchVPNConnectionStatusChanges: @Sendable () -> AnyPublisher<VPNConnectionStatus, Never> = {
        return NotificationCenter.default
            .publisher(for: .AppStateManager.displayStateChange)
            .map {
                let appStageManager = Container.sharedContainer.makeAppStateManager()

                // todo: when VPN connection will be refactored, please try saving lastConnectionIntent
                // inside NETunnelProviderProtocol.providerConfiguration for WG and OpenVPN.
                let propertyManager = Container.sharedContainer.makePropertiesManager()

                return ($0.object as! AppDisplayState).vpnConnectionStatus(appStageManager.activeConnection(), intent: propertyManager.lastConnectionIntent)
            }
            .eraseToAnyPublisher()
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
            serverIPId: self.serverIp.id,
            vpnProtocol: self.vpnProtocol,
            natType: self.natType,
            safeMode: self.safeMode,
            feature: self.server.feature,
            serverName: self.server.name,
            country: self.server.exitCountryCode,
            city: self.server.city
        )
    }
}
