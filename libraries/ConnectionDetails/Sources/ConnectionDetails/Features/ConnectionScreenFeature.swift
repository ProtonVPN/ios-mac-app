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
        public var ipViewState: IPViewFeature.State
        public var connectionDetailsState: ConnectionDetailsFeature.State
        public var isSecureCore: Bool
        public var connectionFeatures: [ConnectionSpec.Feature]

        @SharedReader(.vpnConnectionStatus) public var vpnConnectionStatus: VPNConnectionStatus

        public init(ipViewState: IPViewFeature.State,
                    connectionDetailsState: ConnectionDetailsFeature.State,
                    isSecureCore: Bool,
                    connectionFeatures: [ConnectionSpec.Feature]) {
            self.ipViewState = ipViewState
            self.connectionDetailsState = connectionDetailsState
            self.isSecureCore = isSecureCore
            self.connectionFeatures = connectionFeatures
        }
    }

    @CasePathable
    public enum Action: Equatable {
        case ipViewAction(IPViewFeature.Action)
        case connectionDetailsAction(ConnectionDetailsFeature.Action)
    }

    public init() {}

    public var body: some Reducer<State, Action> {
        Scope(state: \.ipViewState, action: \.ipViewAction) {
            IPViewFeature()
        }
        Scope(state: \.connectionDetailsState, action: \.connectionDetailsAction) {
            ConnectionDetailsFeature()
        }
    }
}

public extension VPNConnectionActual {
    func connectionScreenFeatureState() -> ConnectionScreenFeature.State? {
        guard let vpnServer = server() else {
            return nil
        }
        return ConnectionScreenFeature.State(ipViewState: .init(),
                                             connectionDetailsState: .init(actual: self, vpnServer: vpnServer),
                                             isSecureCore: feature.contains(.secureCore),
                                             connectionFeatures: features(vpnServer: vpnServer))
    }

    private func server() -> VPNServer? {
        @Dependency(\.serverRepository) var repository
        return repository.getFirstServer(filteredBy: [.logicalID(serverModelId)],
                                                      orderedBy: .fastest)
    }

    private func features(vpnServer: VPNServer?) -> [ConnectionSpec.Feature] {
        var features = [ConnectionSpec.Feature]()

        let table: [(ServerFeature, ConnectionSpec.Feature)] = [
            (ServerFeature.tor, ConnectionSpec.Feature.tor),
            (ServerFeature.p2p, ConnectionSpec.Feature.p2p),
            (ServerFeature.streaming, ConnectionSpec.Feature.streaming),
        ]
        for feature in table {
            if self.feature.contains(feature.0) {
                features.append(feature.1)
            }
        }

        if vpnServer?.logical.isVirtual == true {
            features.append(.smart)
        }

        return features
    }
}
