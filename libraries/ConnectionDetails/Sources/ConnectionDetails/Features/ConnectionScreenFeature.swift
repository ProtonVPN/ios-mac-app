//
//  Created on 01/10/2024.
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

import ComposableArchitecture
import Domain
import VPNAppCore
import Foundation
import Localization
import Persistence

@Reducer
public struct ConnectionScreenFeature {

    @Dependency(\.dismiss) var dismiss

    @ObservableState
    public struct State: Equatable {
        public var ipViewState: IPViewFeature.State = .init()

        @SharedReader(.vpnConnectionStatus) public var vpnConnectionStatus: VPNConnectionStatus

        public init?(vpnConnectionStatus: VPNConnectionStatus) {
            guard let actual = vpnConnectionStatus.actual else { return nil }
            isSecureCore = actual.feature.contains(.secureCore)
            
            @Dependency(\.serverRepository) var repository
            let logicalID = actual.serverModelId
            let vpnServer = repository.getFirstServer(filteredBy: [.logicalID(logicalID)],
                                                      orderedBy: .fastest)

            connectionFeatures = Self.connectionFeatures(actual: actual, vpnServer: vpnServer)
            connectionDetailsState = .init(actual: actual, vpnServer: vpnServer)
        }

        public var connectionDetailsState: ConnectionDetailsFeature.State

        public var isSecureCore: Bool

        public var connectionFeatures: [ConnectionSpec.Feature]
        static func connectionFeatures(actual: VPNConnectionActual, vpnServer: VPNServer?) -> [ConnectionSpec.Feature] {
            var features = [ConnectionSpec.Feature]()

            let table: [(ServerFeature, ConnectionSpec.Feature)] = [
                (ServerFeature.tor, ConnectionSpec.Feature.tor),
                (ServerFeature.p2p, ConnectionSpec.Feature.p2p),
                (ServerFeature.streaming, ConnectionSpec.Feature.streaming),
            ]
            for feature in table {
                if actual.feature.contains(feature.0) {
                    features.append(feature.1)
                }
            }

            if vpnServer?.logical.isVirtual == true {
                features.append(.smart)
            }

            return features
        }
    }

    @CasePathable
    public enum Action: Equatable {
        case ipViewAction(IPViewFeature.Action)
        case connectionDetailsAction(ConnectionDetailsFeature.Action)
        /// Watch for changes of VPN connection
        case watchConnectionStatus
        /// Process new VPN connection state
        case newConnectionStatus(VPNConnectionStatus)
    }

    private enum CancelId {
        case watchConnectionStatus
    }

    public init() {}

    public var body: some Reducer<State, Action> {
        Scope(state: \.ipViewState, action: \.ipViewAction) {
            IPViewFeature()
        }
        Scope(state: \.connectionDetailsState, action: \.connectionDetailsAction) {
            ConnectionDetailsFeature()
        }

        Reduce { state, action in
            switch action {
            case .watchConnectionStatus:
                return .publisher {
                    state
                        .$vpnConnectionStatus
                        .publisher
                        .receive(on: UIScheduler.shared)
                        .map(Action.newConnectionStatus)
                }
                .cancellable(id: CancelId.watchConnectionStatus)
            case .newConnectionStatus:
//                TODO: update when new connection
//                state.connectionDetailsState = .init(actual: connectionStatus.actual, vpnServer: nil) status received
                return .none
            default:
                return .none
            }
        }
    }
}

extension VpnProtocol {
    public var description: String {
        switch self {
        case .ike:
            return "IKEv2"
        case .openVpn(let transport):
            return "OpenVPN (\(transport.rawValue.uppercased()))"
        case .wireGuard(let transport):
            return "WireGuard (\(transport.rawValue.uppercased()))"
        }
    }
}
