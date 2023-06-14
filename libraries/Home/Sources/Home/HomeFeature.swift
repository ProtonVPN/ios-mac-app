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

import Theme
import VPNShared

public struct HomeFeature: Reducer {
    /// - Note: might want this as a property of all Reducer types
    public typealias ActionSender = (Action) -> ()

    public struct State: Equatable {
        static let maxConnections = 8

        public var connections: [RecentConnection]

        public var connectionStatus: ConnectionStatusFeature.State

        public init(connections: [RecentConnection], connectionStatus: ConnectionStatusFeature.State) {
            self.connections = connections
            self.connectionStatus = connectionStatus
        }

        mutating func trimConnections() {
            while connections.count > Self.maxConnections,
                  let index = connections.lastIndex(where: \.notPinned) {
                connections.remove(at: index)
            }
        }
    }

    public enum Action: Equatable {
        /// Connect to a given connection specification. Bump it to the top of the
        /// list, if it isn't already pinned.
        case connect(ConnectionSpec)
        case connected
        case disconnect
        /// Pin a recent connection to the top of the list, and remove it from the recent connections.
        case pin(ConnectionSpec)
        /// Remove a connection from the pins, and add it to the top of the recent connections.
        case unpin(ConnectionSpec)
        /// Remove a connection.
        case remove(ConnectionSpec)
        case connectionStatus(ConnectionStatusFeature.Action)
    }

    enum HomeCancellable {
        case connect
    }

    public var body: some ReducerOf<Self> {
        Reduce { state, action in
            switch action {
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
                    connectionDate: .now,
                    connection: spec
                )
                state.connections.insert(recent, at: 0)
                state.trimConnections()
                return .run { send in
                    // Simple state change won't do here because we need to start updating the UI with asterisks so we need to trigger the reducer
                    await send.send(.connectionStatus(.update(ProtectionState.protecting(country: "Poland", ip: "192.168.1.0"))))
                    try await Task.sleep(nanoseconds: 1_000_000_000) // mimic connection
                    // This would normally come somewhere from outside
                    await send.send(.connected)
                }
                .cancellable(id: HomeCancellable.connect)
            case .connected:
                return .send(.connectionStatus(.update(ProtectionState.protected(netShield: .random))))
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
                state.connectionStatus.protectionState = .unprotected(country: "Poland", ip: "192.168.1.0")
                return .cancel(id: HomeCancellable.connect)
            case .connectionStatus:
                return .none
            }
        }
        Scope(state: \.connectionStatus, action: /Action.connectionStatus) {
            ConnectionStatusFeature()
        }
    }

    public init() {}
}

extension RecentConnection {
    public var icon: Image {
        if pinned {
            return Theme.Asset.icPinFilled.swiftUIImage
        } else {
            return Theme.Asset.icClockRotateLeft.swiftUIImage
        }
    }
}

#if DEBUG
extension HomeFeature.State {
    public static let preview: Self = .init(connections: [.pinnedFastest,
                                                          .previousFreeConnection,
                                                          .connectionSecureCore,
                                                          .connectionRegion,
                                                          .connectionSecureCoreFastest],
                                            connectionStatus: .init(protectionState: .protected(netShield: .random)))
}

#endif
