//
//  Created on 28/08/2024.
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
import VPNAppCore
import Domain
import Foundation
import Dependencies
import OrderedCollections

@Reducer
public struct HomeConnectionCardFeature {
    public typealias ActionSender = (Action) -> Void

    @ObservableState
    public struct State: Equatable {
        @SharedReader(.userTier) public var userTier: Int?
        @SharedReader(.vpnConnectionStatus) public var vpnConnectionStatus: VPNConnectionStatus
        @SharedReader(.recents) public var recents: OrderedSet<RecentConnection>
        @SharedReader(.defaultConnectionPreference) var defaultConnectionPreference: DefaultConnectionPreference
        @SharedReader(.secureCoreToggle) var secureCoreToggle: Bool

        public var showChangeServerButton: Bool {
            if case .connected = vpnConnectionStatus {
                guard let userTier else { return true }

                return userTier.isFreeTier
            }
            return false
        }

        package var headerModel: ConnectionCardHeaderModel {
            ConnectionCardHeaderModel(connectionStatus: vpnConnectionStatus, userTier: userTier ?? .freeTier)
        }

        public var serverChangeAvailability: ServerChangeAuthorizer.ServerChangeAvailability?

        public var presentedSpec: ConnectionSpec {
            switch vpnConnectionStatus {
            case .disconnected, .disconnecting, .resolving(.none, _):
                @Dependency(\.defaultConnectionResolver) var resolver
                return resolver.connectionSpec(
                    preference: defaultConnectionPreference,
                    recents: recents,
                    secureCore: secureCoreToggle
                )
            case .connected(let connectionSpec, _),
                    .connecting(let connectionSpec, _),
                    .resolving(.some(let connectionSpec), _):
                return connectionSpec
            }
        }

        public var presentedServer: Server? {
            // Ignore the server object on vpnConnectionStatus when the connection is `disconnecting`,
            // as the `disconnecting` state should look the same as the `disconnected` state.
            if case .disconnecting = vpnConnectionStatus {
                return nil
            }
            return vpnConnectionStatus.server
        }

        public init() {
            @Dependency(\.serverChangeAuthorizer) var authorizer
            serverChangeAvailability = authorizer.serverChangeAvailability()
        }
    }

    public enum Action: Equatable {
        @CasePathable
        public enum Delegate: Equatable {
            case connect(ConnectionSpec)
            case disconnect
            case tapAction
            case changeServerButtonTapped

            // Header
            case defaultConnectionTapped
        }

        case delegate(Delegate)
        case watchConnectionStatus
        case newConnectionStatus(VPNConnectionStatus)
    }

    private enum CancelId {
        case watchConnectionStatus
    }

    public init() {}

    public var body: some Reducer<State, Action> {
        Reduce { state, action in
            switch action {
            case .delegate:
                return .none
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
                @Dependency(\.serverChangeAuthorizer) var authorizer
                state.serverChangeAvailability = authorizer.serverChangeAvailability()

                return .none
            }
        }
    }
}

package enum ConnectionCardHeaderModel: Equatable {
    case resolving
    case disconnected(isPaid: Bool)
    case connected
    case connecting

    init(connectionStatus: VPNConnectionStatus, userTier: Int) {
        switch connectionStatus {
        case .resolving:
            self = .resolving

        case .disconnected, .disconnecting:
            self = .disconnected(isPaid: userTier.isPaidTier)

        case .connected:
            self = .connected

        case .connecting:
            self = .connecting
        }
    }
}
