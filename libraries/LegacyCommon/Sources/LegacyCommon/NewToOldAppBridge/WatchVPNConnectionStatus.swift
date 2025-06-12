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

@available(macOS 13, *)
@available(tvOS, unavailable)
extension VPNConnectionStatusPublisherKey: @retroactive DependencyKey {
    public static let displayStateStream: () -> AsyncStream<VPNConnectionStatus> = {
        return NotificationCenter.default
            .notifications(named: AppEvent.appStateManagerStateChange.name)
            .map {
                let appStateManager = Container.sharedContainer.makeAppStateManager()

                let propertyManager = Container.sharedContainer.makePropertiesManager()
                let connectedDate = await Container.sharedContainer.makeVpnManager().connectedDate()

                return ($0.object as! AppDisplayState)
                    .vpnConnectionStatus(appStateManager.activeConnection(),
                                         lastPreparedServer: propertyManager.lastPreparedServer,
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

@available(macOS 13, *)
@available(iOS, unavailable)
@available(tvOS, unavailable)
extension VPNConnectionStatusKey: @retroactive DependencyKey {
    public static var liveValue: @Sendable () async -> VPNConnectionStatus = {
        let appStateManager = Container.sharedContainer.makeAppStateManager()
        let propertyManager = Container.sharedContainer.makePropertiesManager()

        return appStateManager.displayState.vpnConnectionStatus(
            appStateManager.activeConnection(),
            lastPreparedServer: propertyManager.lastPreparedServer,
            intent: propertyManager.lastConnectionIntent,
            connectedDate: await Container.sharedContainer.makeVpnManager().connectedDate()
        )
    }
}

// MARK: - AppDisplayState -> VPNConnectionStatus

extension AppDisplayState {
    func vpnConnectionStatus(
        _ connectionConfiguration: ConnectionConfiguration?,
        lastPreparedServer: ServerModel?,
        intent: ConnectionSpec,
        connectedDate: Date?
    ) -> VPNConnectionStatus {
        let resolvedConnection = connectionConfiguration?.vpnConnectionActual(connectedDate: connectedDate)
        switch self {
        case .connected:
#if targetEnvironment(simulator)
            return .connected(intent, VPNConnectionActual.mock())
#endif
            return .connected(intent, resolvedConnection)

        case .connecting:
            // `AppStateManager` posts a notification before `connectionConfiguration` is updated with the target server.
            // Changing this would require complex changes to legacy connection logic, so let's grab the target server
            // from properties manager instead.
            let server = lastPreparedServer.flatMap { Server.withRandomEndpoint(from: $0) } ?? resolvedConnection?.server
            return .connecting(intent, server)

        case .loadingConnectionInfo:
            return .resolving(intent, resolvedConnection)

        case .disconnecting:
            return .disconnecting(intent, resolvedConnection)

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

extension Server {
    static func withRandomEndpoint(from legacyModel: ServerModel) -> Server? {
        let server = VPNServer(legacyModel: legacyModel)

        guard let endpoint = server.endpoints.randomElement() else {
            log.error("Server has no endpoints")
            return nil
        }

        return Server(logical: server.logical, endpoint: endpoint)
    }
}
