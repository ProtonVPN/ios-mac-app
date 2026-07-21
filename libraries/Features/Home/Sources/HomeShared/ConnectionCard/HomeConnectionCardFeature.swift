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
import Connection
import Dependencies
import Domain
import Foundation
import OrderedCollections
import VPNAppCore

@Reducer
public struct HomeConnectionCardFeature {
    public typealias ActionSender = (Action) -> Void

    @ObservableState
    public struct State: Equatable {
        @SharedReader(.userTier) public var userTier: Int?
        @SharedReader(.connectionState) public var connectionState: ConnectionState
        @SharedReader(.recentConnections) public var recents
        @SharedReader(.storedDefaultConnectionPreference) var defaultConnectionPreference
        @SharedReader(.secureCoreToggle) var secureCoreToggle: Bool

        public var showChangeServerButton: Bool {
            if case .connected = connectionState {
                guard let userTier else { return true }

                return userTier.isFreeTier
            }
            return false
        }

        package var headerModel: ConnectionCardHeaderModel {
            ConnectionCardHeaderModel(connectionState: connectionState, userTier: userTier ?? .freeTier)
        }

        public var serverChangeAvailability: ServerChangeAuthorizer.ServerChangeAvailability?

        public var presentedSpec: ConnectionSpec {
            // Prefer the spec embedded in the current state (including prior intent during
            // `.resolving` for cold-start continuity); fall back to the user's default
            // connection only when we have nothing to show.
            if let spec = connectionState.resolvedSpec {
                return spec
            }
            @Dependency(\.defaultConnectionResolver) var resolver
            return resolver.connectionSpec(
                preference: defaultConnectionPreference ?? .fastest,
                recents: recents ?? [],
                secureCore: secureCoreToggle
            )
        }

        public var presentedServer: Server? {
            // Ignore the server object on connectionState when the connection is `disconnecting`,
            // as the `disconnecting` state should look the same as the `disconnected` state.
            if case .disconnecting = connectionState {
                return nil
            }
            return connectionState.resolvedServer
        }

        public init() {
            @Dependency(\.serverChangeAuthorizer) var authorizer
            self.serverChangeAvailability = authorizer.serverChangeAvailability()
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
        case newConnectionState(ConnectionState)
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
                        .$connectionState
                        .publisher
                        .receive(on: UIScheduler.shared)
                        .map(Action.newConnectionState)
                }
                .cancellable(id: CancelId.watchConnectionStatus)

            case .newConnectionState:
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

    init(connectionState: ConnectionState, userTier: Int) {
        switch connectionState {
        case .resolving:
            self = .resolving

        case .disconnected, .disconnecting, .killSwitchActive:
            self = .disconnected(isPaid: userTier.isPaidTier)

        case .connected:
            self = .connected

        case .connecting:
            self = .connecting
        }
    }
}
