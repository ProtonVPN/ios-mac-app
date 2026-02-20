//
//  Created on 08/01/2026 by Max Kupetskyi.
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

import CommonNetworking
import ComposableArchitecture
import Dependencies
import Domain
import Foundation
import LegacyCommon
import VPNAppCore
import VPNShared

@Reducer
public struct ServerItemFeature {
    public init() {}

    @ObservableState
    public struct State: Equatable, Identifiable, Sendable {
        let serverInfo: ServerInfo
        public let serverType: ServerType

        public var id: String { serverInfo.logical.id }

        @SharedReader(.vpnConnectionStatus) var vpnConnectionStatus: VPNConnectionStatus
        @SharedReader(.userTier) var userTier: Int?

        // Computed properties
        var city: String {
            serverInfo.logical.city ?? ""
        }

        public var isUsersTierTooLow: Bool {
            userTier ?? 0 < serverInfo.logical.tier
        }

        public var underMaintenance: Bool {
            @Dependency(\.propertiesManager) var propertiesManager
            return serverInfo.logical.isUnderMaintenance
                || serverInfo.protocolSupport.isDisjoint(with: propertiesManager.currentProtocolSupport)
        }

        var isConnected: Bool {
            guard case let .connected(_, actual) = vpnConnectionStatus,
                  actual?.server.logical.id == serverInfo.logical.id else {
                return false
            }
            return true
        }

        var isConnecting: Bool {
            guard case let .connecting(_, server) = vpnConnectionStatus,
                  server?.logical.id == serverInfo.logical.id else {
                return false
            }
            return true
        }

        var isCurrentlyConnected: Bool {
            isConnected || isConnecting
        }

        var canConnect: Bool {
            !isUsersTierTooLow && !underMaintenance
        }

        var viaCountry: (name: String, code: String)? {
            if serverType == .secureCore {
                return (serverInfo.logical.entryCountry, serverInfo.logical.entryCountryCode)
            }
            return nil
        }
    }

    public enum Action: BindableAction {
        case binding(BindingAction<State>)
        case connectTapped
        case connectionStatusChanged(VPNConnectionStatus)

        case streamingInfoRequested

        case connectRequested(VPNServer)
        case disconnectRequested
        case stopConnectingRequested
        case showUpgradeUpsell
        case showMaintenanceAlert
    }

    @Dependency(\.serverRepository) var serverRepository

    public var body: some ReducerOf<Self> {
        BindingReducer()

        Reduce { state, action in
            switch action {
            case .connectTapped:
                handleConnect(state: state)

            case .connectionStatusChanged:
                .none

            case .binding:
                .none

            case .streamingInfoRequested:
                .none

            case .connectRequested, .disconnectRequested, .stopConnectingRequested, .showUpgradeUpsell, .showMaintenanceAlert:
                .none
            }
        }
    }

    // MARK: - Private Methods

    private func handleConnect(state: State) -> Effect<Action> {
        print("Connect requested by clicking on Server item")

        if state.underMaintenance {
            print("Connect rejected because server is in maintenance")
            return .send(.showMaintenanceAlert)
        }

        if state.isUsersTierTooLow {
            print("Connect rejected because user plan is too low")
            return .send(.showUpgradeUpsell)
        }

        if state.isConnected {
            print("VPN is connected already. Will be disconnected.")
            return .send(.disconnectRequested)
        }

        if state.isConnecting {
            print("VPN is connecting. Will stop connecting.")
            return .send(.stopConnectingRequested)
        }

        // Get the actual server to connect to
        guard let server = serverRepository.getFirstServer(
            filteredBy: [.logicalID(state.serverInfo.logical.id)],
            orderedBy: .fastest
        ) else {
            print("No server found with logical ID \(state.serverInfo.logical.id)")
            return .none
        }

        print("Will connect to \(server.logical.name)")
        return .send(.connectRequested(server))
    }
}
