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

import SwiftUI
import Foundation

import Dependencies
import ComposableArchitecture

import Domain
import Theme
import VPNShared
import VPNAppCore
import ProtonCoreUIFoundations
import ConnectionDetails

import CasePaths

@available(iOS 17, *)
@Reducer
public struct HomeFeature {
    /// - Note: might want this as a property of all Reducer types
    public typealias ActionSender = (Action) -> Void

    @Dependency(\.serverChangeAuthorizer) var authorizer

    @Reducer(state: .equatable)
    public enum Destination {
        case changeServer(ChangeServerFeature)
        case connectionDetails(ConnectionScreenFeature)
    }

    @ObservableState
    public struct State: Equatable {
        static let maxConnections = 8

        public var connections: [RecentConnection]

        public var map: HomeMapFeature.State
        public var connectionCard: HomeConnectionCardFeature.State
        public var connectionStatus: ConnectionStatusFeature.State
        public var sharedProperties: SharedPropertiesFeature.State
        @SharedReader(.vpnConnectionStatus) var vpnConnectionStatus: VPNConnectionStatus

        @Presents public var destination: Destination.State?

        public init(connections: [RecentConnection] = [],
                    connectionStatus: ConnectionStatusFeature.State = .init()) {
            self.connections = connections
            self.connectionStatus = connectionStatus
            self.connectionCard = .init()
            self.sharedProperties = .init()
            self.map = .init()
        }

        mutating func trimConnections() {
            @Dependency(\.storage) var storage
            while connections.count > Self.maxConnections,
                  let index = connections.lastIndex(where: \.notPinned) {
                connections.remove(at: index)
            }
            try? storage.set(connections, forKey: "RecentConnections")
        }
    }

    @CasePathable
    public enum Action {
        /// Connect to a given connection specification. Bump it to the top of the
        /// list, if it isn't already pinned.
        case connect(ConnectionSpec)
        case changeServer
        case disconnect
        /// Pin a recent connection to the top of the list, and remove it from the recent connections.
        case pin(ConnectionSpec)
        /// Remove a connection from the pins, and add it to the top of the recent connections.
        case unpin(ConnectionSpec)
        /// Remove a connection.
        case remove(ConnectionSpec)

        case map(HomeMapFeature.Action)
        case connectionStatus(ConnectionStatusFeature.Action)
        case connectionCard(HomeConnectionCardFeature.Action)
        case sharedProperties(SharedPropertiesFeature.Action)
        case connectionDetails(ConnectionScreenFeature.Action)

        /// Start bug report flow
        case helpButtonPressed

        case loadConnections

        case destination(PresentationAction<Destination.Action>)
    }

    private enum CancelId {
        case watchConnectionStatus
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
        Reduce { state, action in
            switch action {
            case .sharedProperties:
                return .none
            case let .connect(spec):
                var pinned = false

                if let index = state.connections.firstIndex(where: {
                    $0.connection == spec
                }) {
                    pinned = state.connections[index].pinned
                    state.connections.remove(at: index)
                }
                let recent = RecentConnection(
                    pinned: pinned,
                    underMaintenance: false,
                    connectionDate: Date(),
                    connection: spec
                )
                state.connections.insert(recent, at: 0)
                state.trimConnections()

                return .run { send in
                    @Dependency(\.connectToVPN) var connectToVPN
                    try? await connectToVPN(spec)
                    authorizer.registerServerChange(connectedAt: .now) // TODO: [redesign] is this a good place to do it?
                }
            case .changeServer:
                // TODO: [redesign] Do an actual server change
                return .concatenate([
                    .send(.disconnect),
                    .send(.connect(.defaultFastest))
                ])

            case let .pin(spec):
                guard let index = state.connections.firstIndex(where: {
                    $0.connection == spec
                }) else {
                    state.trimConnections()
                    return .none
                }

                state.connections[index].pinned = true
                state.trimConnections()
                return .none

            case let .unpin(spec):
                guard let index = state.connections.firstIndex(where: {
                    $0.connection == spec
                }) else {
                    state.trimConnections()
                    return .none
                }

                state.connections[index].pinned = false
                state.trimConnections()
                return .none

            case let .remove(spec):
                state.connections.removeAll {
                    $0.connection == spec
                }
                state.trimConnections()
                return .none

            case .disconnect:
                state.connectionStatus.protectionState = .unprotected
                return .run { send in
                    @Dependency(\.disconnectVPN) var disconnectVPN
                    try? await disconnectVPN()
                }

            case .connectionStatus:
                return .none
            case .connectionDetails:
                return .none // Will be handled up the tree of reducers
            case .helpButtonPressed:
                return .none
            case .loadConnections:
                @Dependency(\.storage) var storage
                if let connections = try? storage.get([RecentConnection].self, forKey: "RecentConnections") {
                    state.connections = connections
                }
                return .none
            case .connectionCard(.delegate(let action)):
                switch action {
                case .connect(let spec):
                    return .send(.connect(spec))
                case .disconnect:
                    return .send(.disconnect)
                case .tapAction:
                    if let connectionState = ConnectionScreenFeature.State(vpnConnectionStatus: state.vpnConnectionStatus) {
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
                    if authorizer.serverChangeAvailability() == .available {
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

extension RecentConnection {
    public var icon: Image {
        if pinned {
            return IconProvider.pinFilled
        } else {
            return IconProvider.clockRotateLeft
        }
    }
}

#if DEBUG
@available(iOS 17, *)
extension HomeFeature {
    public static let previewState: State = .init(connections: [.pinnedFastest,
                                                                .previousFreeConnection,
                                                                .connectionSecureCore,
                                                                .connectionRegion,
                                                                .connectionSecureCoreFastest],
                                                  connectionStatus: .init())
}
#endif
