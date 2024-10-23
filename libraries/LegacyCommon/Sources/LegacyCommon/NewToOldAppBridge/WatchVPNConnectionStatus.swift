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

extension VPNConnectionStatusPublisherKey: DependencyKey {

    @available(macOS 12, *)
    public static let displayStateStream: () -> AsyncStream<VPNConnectionStatus> = {
        return NotificationCenter.default
            .notifications(named: .AppStateManager.displayStateChange)
            .map {
                let appStateManager = Container.sharedContainer.makeAppStateManager()

                // todo: when VPN connection will be refactored, please try saving lastConnectionIntent
                // inside NETunnelProviderProtocol.providerConfiguration for WG and OpenVPN.
                let propertyManager = Container.sharedContainer.makePropertiesManager()
                let connectedDate = await Container.sharedContainer.makeVpnManager().connectedDate()

                return ($0.object as! AppDisplayState)
                    .vpnConnectionStatus(appStateManager.activeConnection(),
                                         intent: propertyManager.lastConnectionIntent,
                                         connectedDate: connectedDate)
            }
            .eraseToStream()
    }

    public static let liveValue: () -> AsyncStream<VPNConnectionStatus> = {
        if #available(macOS 12, *) {
            return displayStateStream()
        } else {
            return .finished
        }
    }

}

extension VPNConnectionStatusKey: DependencyKey {
    public static var liveValue: @Sendable () async -> VPNConnectionStatus = {
        let appStateManager = Container.sharedContainer.makeAppStateManager()
        let propertyManager = Container.sharedContainer.makePropertiesManager()

        return appStateManager.displayState.vpnConnectionStatus(
            appStateManager.activeConnection(),
            intent: propertyManager.lastConnectionIntent,
            connectedDate: await Container.sharedContainer.makeVpnManager().connectedDate()
        )
    }
}

// MARK: - AppDisplayState -> VPNConnectionStatus

extension AppDisplayState {

    func vpnConnectionStatus(_ connectionConfiguration: ConnectionConfiguration?, intent: ConnectionSpec, connectedDate: Date?) -> VPNConnectionStatus {
        switch self {
        case .connected:
            return .connected(intent, connectionConfiguration?.vpnConnectionActual(connectedDate: connectedDate))

        case .connecting:
            return .connecting(intent, connectionConfiguration?.vpnConnectionActual(connectedDate: connectedDate))

        case .loadingConnectionInfo:
            return .loadingConnectionInfo(intent, connectionConfiguration?.vpnConnectionActual(connectedDate: connectedDate))

        case .disconnecting:
            return .disconnecting(intent, connectionConfiguration?.vpnConnectionActual(connectedDate: connectedDate))

        case .disconnected:
            return .disconnected
        }
    }
}

extension ConnectionConfiguration {
    func vpnConnectionActual(connectedDate: Date?) -> VPNConnectionActual {
        // Reduce ambiguity by returning only the single server ip/endpoint we are connected to,
        // even if this logical has multiple endpoints.
        let serverWithOnlyActiveEndpoint = Server(
            logical: VPNServer(legacyModel: server).logical,
            endpoint: ServerEndpoint(legacyModel: serverIp)
        )

        return VPNConnectionActual(
            connectedDate: connectedDate,
            vpnProtocol: self.vpnProtocol,
            natType: self.natType,
            safeMode: self.safeMode,
            server: serverWithOnlyActiveEndpoint
        )
    }
}
