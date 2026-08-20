//
//  Created on 07/10/2024.
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

import CommonNetworking
import ComposableArchitecture
import Connection
import Domain
import Foundation
import OrderedCollections
import Persistence
import SwiftUI
import VPNAppCore
import WidgetKit

@Reducer
public struct RecentsFeature {
    public typealias ActionSender = (Action) -> Void

    @ObservableState
    public struct State: Equatable {
        @SharedReader(.connectionState) public var connectionState: ConnectionState

        @SharedReader(.storedDefaultConnectionPreference) private var defaultConnectionPreference
        @Shared(.recentConnections) fileprivate var recentConnections

        /// List of recent connections, minus the default connection if its not pinned
        public var recentConnectionList: OrderedSet<RecentConnection> {
            @Dependency(\.connectionInventory) var presenter
            return presenter.recentConnectionList(
                defaultConnectionPreference: defaultConnectionPreference ?? .fastest,
                recents: recentConnections ?? [],
                currentConnection: connectionState.resolvedSpec
            )
        }

        @SharedReader(.userTier) public var userTier: VpnTier?
        public init() {
            if recentConnections == nil {
                $recentConnections.withLock {
                    $0 = []
                }
            }
        }
    }

    public enum Action {
        case connectionEstablished(ConnectionSpec, display: RecentConnection.ServerDisplay?)
        case serverListUpdated
        case pin(RecentConnection)
        case unpin(RecentConnection)
        case remove(RecentConnection)
        case watchConnectionStatus
        case newConnectionState(ConnectionState)
        case upsellTapped(BannerType)

        case delegate(Delegate)

        @CasePathable
        public enum Delegate: Equatable {
            case connect(ConnectionSpec, isPinned: Bool)
            case upsellTapped(BannerType)
        }
    }

    private enum CancelId {
        case watchConnectionStatus
    }

    @Dependency(\.date) var date

    public init() {}

    public var body: some Reducer<State, Action> {
        Reduce { state, action in
            switch action {
            case .watchConnectionStatus:
                return .merge(
                    .publisher {
                        state
                            .$connectionState
                            .publisher
                            .removeDuplicates()
                            .receive(on: UIScheduler.shared)
                            .map(Action.newConnectionState)
                    },
                    .publisher {
                        NotificationCenter.default
                            .publisher(for: ServerListUpdateNotification.name)
                            .receive(on: UIScheduler.shared)
                            .map { _ in Action.serverListUpdated }
                    }
                )
                .cancellable(id: CancelId.watchConnectionStatus)

            case let .upsellTapped(type):
                return .send(.delegate(.upsellTapped(type)))

            case let .newConnectionState(connectionState):
                guard case let .connected(tunnelConfig, connectionData) = connectionState else { return .none }
                return .send(.connectionEstablished(
                    tunnelConfig.connectionSpec,
                    display: RecentConnection.ServerDisplay(logical: connectionData.currentPeer.logical)
                ))

            case let .connectionEstablished(spec, display):
                withAnimation {
                    state.$recentConnections.withLock { $0?.updateList(with: spec, display: display) }
                    WidgetCenter.shared.reloadAllTimelines()
                }

                return .none

            case .serverListUpdated:
                // The list changed under the precomputed recents, so rewrite their display fields.
                @Dependency(\.serverRepository) var serverRepository
                state.$recentConnections.withLock { $0 = $0?.refreshingServerDisplay(from: serverRepository) }
                WidgetCenter.shared.reloadAllTimelines()
                return .none

            case let .pin(recent):
                withAnimation {
                    state.$recentConnections.withLock { $0?.pin(recent: recent, pinnedDate: date.now) }
                    WidgetCenter.shared.reloadAllTimelines()
                }
                return .none

            case let .unpin(recent):
                withAnimation {
                    state.$recentConnections.withLock { $0?.unpin(recent: recent) }
                    WidgetCenter.shared.reloadAllTimelines()
                }
                return .none

            case let .remove(recent):
                withAnimation {
                    _ = state.$recentConnections.withLock { $0?.remove(recent) }
                    WidgetCenter.shared.reloadAllTimelines()
                }
                return .none

            case .delegate:
                return .none
            }
        }
    }
}
