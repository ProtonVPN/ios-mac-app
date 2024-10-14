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

import Domain
import ComposableArchitecture
import Foundation
import VPNAppCore

@Reducer
public struct RecentsFeature {
    public typealias ActionSender = (Action) -> Void

    @ObservableState
    public struct State: Equatable {
        static let maxConnections: Int = 8

        @SharedReader(.vpnConnectionStatus)
        public var vpnConnectionStatus: VPNConnectionStatus

        public package(set) var recents: [RecentConnection] = .readFromStorage()

        public init(recents: [RecentConnection]) {
            self.recents = recents
        }

        public init() {}
    }

    @CasePathable
    public enum Action {
        case connectionEstablished(ConnectionSpec)
        case pin(ConnectionSpec)
        case unpin(ConnectionSpec)
        case remove(ConnectionSpec)

        @CasePathable
        public enum Delegate: Equatable {
            case connect(ConnectionSpec)
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
            case .watchConnectionStatus:
                return .publisher {
                    state
                        .$vpnConnectionStatus
                        .publisher
                        .receive(on: UIScheduler.shared)
                        .map(Action.newConnectionStatus)
                }
                .cancellable(id: CancelId.watchConnectionStatus)

            case .newConnectionStatus(let connectionStatus):
                guard case .connected = connectionStatus,
                      let spec = connectionStatus.spec else { return .none }
                return .send(.connectionEstablished(spec))

            case .connectionEstablished(let spec):
                var pinned = false
                if let index = state.recents.index(for: spec) {
                    pinned = state.recents[index].pinned
                    state.recents.remove(at: index)
                }
                let recent = RecentConnection(
                    pinned: pinned,
                    underMaintenance: false,
                    connectionDate: Date(),
                    connection: spec
                )
                state.recents.insert(recent, at: 0)
                state.recents.trimAndSortList()
                return .none
            case let .pin(spec):
                guard let index = state.recents.index(for: spec) else {
                    return .none
                }

                state.recents[index].pinned = true
                state.recents.trimAndSortList()
                return .none

            case let .unpin(spec):
                guard let index = state.recents.index(for: spec) else {
                    return .none
                }

                state.recents[index].pinned = false
                state.recents.trimAndSortList()
                return .none

            case let .remove(spec):
                state.recents.removeAll {
                    $0.connection == spec
                }
                state.recents.trimAndSortList()
                return .none
            case .delegate:
                return .none
            }
        }
    }
}
