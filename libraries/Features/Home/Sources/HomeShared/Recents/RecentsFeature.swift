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

import ComposableArchitecture
import Connection
import Domain
import Foundation
import OrderedCollections
import SwiftUI
import VPNAppCore
import VPNShared

@Reducer
public struct RecentsFeature {
    public typealias ActionSender = (Action) -> Void

    @ObservableState
    public struct State: Equatable {
        @SharedReader(.connectionState) public var connectionState: ConnectionState

        @SharedReader(.defaultConnectionPreference) private var defaultConnectionPreference
        @Shared(.recents) fileprivate var recents: OrderedSet<RecentConnection>

        /// List of recent connections, minus the default connection if its not pinned
        public var recentConnectionList: OrderedSet<RecentConnection> {
            @Dependency(\.connectionInventory) var presenter
            return presenter.recentConnectionList(
                defaultConnectionPreference: defaultConnectionPreference,
                recents: recents,
                currentConnection: connectionState.resolvedIntent?.spec
            )
        }

        @SharedReader(.userTier) public var userTier: Int?

        public init() {
            @Dependency(\.recentsStorage) var recentsStorage
            $recents.withLock { $0 = recentsStorage.readFromStorage() }
        }
    }

    public enum Action {
        case connectionEstablished(ConnectionSpec)
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

    @Dependency(\.recentsStorage) var recentsStorage
    @Dependency(\.date) var date

    public init() {}

    public var body: some Reducer<State, Action> {
        Reduce { state, action in
            switch action {
            case .watchConnectionStatus:
                return .publisher {
                    state
                        .$connectionState
                        .publisher
                        .removeDuplicates()
                        .receive(on: UIScheduler.shared)
                        .map(Action.newConnectionState)
                }
                .cancellable(id: CancelId.watchConnectionStatus)

            case let .upsellTapped(type):
                return .send(.delegate(.upsellTapped(type)))

            case let .newConnectionState(connectionState):
                guard case let .connected(intent, _, _, _) = connectionState else { return .none }
                return .send(.connectionEstablished(intent.spec))

            case let .connectionEstablished(spec):
                withAnimation {
                    state.$recents.withLock { $0.updateList(with: spec) }
                }
                recentsStorage.saveToStorage(state.recents)

                return .none

            case let .pin(recent):
                withAnimation {
                    state.$recents.withLock { $0.pin(recent: recent, pinnedDate: date.now) }
                }
                recentsStorage.saveToStorage(state.recents)
                return .none

            case let .unpin(recent):
                withAnimation {
                    state.$recents.withLock { $0.unpin(recent: recent) }
                }
                recentsStorage.saveToStorage(state.recents)
                return .none

            case let .remove(recent):
                _ = withAnimation {
                    state.$recents.withLock { $0.remove(recent) }
                }
                recentsStorage.saveToStorage(state.recents)
                return .none

            case .delegate:
                return .none
            }
        }
    }
}
