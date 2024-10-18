//
//  Created on 17.05.23.
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
import Domain
import VPNAppCore
import ConnectionDetails

@available(iOS 17, *)
@Reducer
public struct HomeFeature {
    @Dependency(\.serverChangeAuthorizer) private var authorizer

    @Reducer(state: .equatable)
    public enum Destination {
        case changeServer(ChangeServerFeature)
        case connectionDetails(ConnectionScreenFeature)
    }

    @ObservableState
    public struct State: Equatable {

        public var map: HomeMapFeature.State
        public var recents: RecentsFeature.State
        public var connectionCard: HomeConnectionCardFeature.State
        public var connectionStatus: ConnectionStatusFeature.State
        public var sharedProperties: SharedPropertiesFeature.State

        @SharedReader(.vpnConnectionStatus)
        public var vpnConnectionStatus: VPNConnectionStatus

        @Presents
        public var destination: Destination.State?

        public init() {
            self.connectionStatus = .init()
            self.connectionCard = .init()
            self.sharedProperties = .init()
            self.recents = .init()
            self.map = .init()
        }
    }

    @CasePathable
    public enum Action {
        /// Connect to a given connection specification. Bump it to the top of the
        /// list, if it isn't already pinned.
        case connect(ConnectionSpec)
        case changeServer
        case disconnect

        case map(HomeMapFeature.Action)
        case recents(RecentsFeature.Action)
        case connectionStatus(ConnectionStatusFeature.Action)
        case connectionCard(HomeConnectionCardFeature.Action)
        case sharedProperties(SharedPropertiesFeature.Action)
        case connectionDetails(ConnectionScreenFeature.Action)

        /// Start bug report flow
        case helpButtonPressed

        case destination(PresentationAction<Destination.Action>)
    }

    public var body: some Reducer<State, Action> {
        Scope(state: \.sharedProperties, action: \.sharedProperties) {
            SharedPropertiesFeature()
        }
        Scope(state: \.map, action: \.map) {
            HomeMapFeature()
        }
        Scope(state: \.connectionCard, action: \.connectionCard) {
            HomeConnectionCardFeature()
        }
        Scope(state: \.connectionStatus, action: \.connectionStatus) {
            ConnectionStatusFeature()
        }
        Scope(state: \.recents, action: \.recents) {
            RecentsFeature()
        }
        Reduce { state, action in
            switch action {
            case .recents(.delegate(.connect(let spec))):
                return .send(.connect(spec))
            case .recents:
                return .none
            case .sharedProperties:
                return .none
            case let .connect(spec):
                return .run { send in
                    @Dependency(\.connectToVPN) var connectToVPN
                    try? await connectToVPN(spec)

                    authorizer.registerServerChange(connectedAt: .now) // TODO: [redesign] is this a good place to do it?
                    await send(.recents(.connectionEstablished(spec)))
                }
            case .changeServer:
                // TODO: [redesign, VPNAPPL-2351] Do an actual server change
                return .concatenate([
                    .send(.disconnect),
                    .send(.connect(.defaultFastest))
                ])

            case .disconnect:
                state.connectionStatus.protectionState = .unprotected
                return .run { send in
                    @Dependency(\.disconnectVPN) var disconnectVPN
                    try? await disconnectVPN()
                }

            case .connectionStatus:
                return .none
            case .connectionDetails:
                return .none
            case .helpButtonPressed:
                return .none
            case .connectionCard(.delegate(let action)):
                switch action {
                case .connect:
                    return .send(.connect(.init()))
                case .disconnect:
                    return .send(.disconnect)
                case .tapAction:
                    if let connectionState = state.vpnConnectionStatus.actual?.connectionScreenFeatureState() {
                        state.destination = .connectionDetails(connectionState)
                    }
                    return .none
                case .changeServerButtonTapped:
                    let availability = authorizer.serverChangeAvailability()
                    if case .available = availability {
                        return .send(.changeServer)
                    }
                    state.destination = .changeServer(.init(serverChangeAvailability: availability))
                    return .none
                }
            case .connectionCard:
                return .none
            case .destination(let action):
                switch action {
                case .presented(.changeServer(.buttonTapped)):
                    if case .available = authorizer.serverChangeAvailability() {
                        state.destination = nil
                        return .send(.changeServer)
                    } else {
                        // TODO: [redesign] Show upsell
                        return .none
                    }
                default:
                    return .none
                }
            case .map:
                return .none
            }
        }
        .ifLet(\.$destination, action: \.destination)
    }

    public init() {}
}
