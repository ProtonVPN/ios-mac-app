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
import VPNShared

@Reducer
public struct RecentsFeature {
    public typealias ActionSender = (Action) -> Void

    @ObservableState
    public struct State: Equatable {
        @SharedReader(.vpnConnectionStatus)
        public var vpnConnectionStatus: VPNConnectionStatus

        public package(set) var recents: [RecentConnection]

        public init() {
            @Dependency(\.recentsStorage) var recentsStorage
            recents = recentsStorage.elements()
        }
    }

    @CasePathable
    public enum Action {
        case connectionEstablished(ConnectionSpec)
        case pin(ConnectionSpec)
        case unpin(ConnectionSpec)
        case remove(ConnectionSpec)
        case watchConnectionStatus
        case newConnectionStatus(VPNConnectionStatus)

        case delegate(Delegate)

        @CasePathable
        public enum Delegate: Equatable {
            case connect(ConnectionSpec)
        }
    }

    private enum CancelId {
        case watchConnectionStatus
    }

    @Dependency(\.recentsStorage) var recentsStorage

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
                guard case .connected = connectionStatus else { return .none }
                guard let spec = connectionStatus.spec else {
                    log.info("Unable to generate spec for connection status: \(connectionStatus)")
                    return .none
                }
                return .send(.connectionEstablished(spec))

            case .connectionEstablished(let spec):
                recentsStorage.updateList(spec)
                state.recents = recentsStorage.elements()
                return .none

            case let .pin(spec):
                recentsStorage.pin(spec)
                state.recents = recentsStorage.elements()
                return .none

            case let .unpin(spec):
                recentsStorage.unpin(spec)
                state.recents = recentsStorage.elements()
                return .none

            case let .remove(spec):
                recentsStorage.remove(spec)
                state.recents = recentsStorage.elements()
                return .none

            case .delegate:
                return .none
            }
        }
    }
}
