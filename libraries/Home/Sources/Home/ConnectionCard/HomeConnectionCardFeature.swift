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

@Reducer
public struct HomeConnectionCardFeature {
    
    public typealias ActionSender = (Action) -> Void

    @ObservableState
    public struct State: Equatable {
        @SharedReader(.userTier) public var userTier: Int
        @SharedReader(.vpnConnectionStatus) public var vpnConnectionStatus: VPNConnectionStatus
        public var showChangeServerButton: Bool = false
        public var serverChangeAvailability: ServerChangeAuthorizer.ServerChangeAvailability?

        public init() { }

        public var presentedSpec: ConnectionSpec {
            switch vpnConnectionStatus {
            case .disconnected:
                return .init(location: .fastest, features: [])
            case .connected(let connectionSpec, _),
                    .connecting(let connectionSpec, _),
                    .loadingConnectionInfo(let connectionSpec, _),
                    .disconnecting(let connectionSpec, _):
                return connectionSpec
            }
        }
    }

    public enum Action: Equatable {
        @CasePathable
        public enum Delegate: Equatable {
            case connect/*(ConnectionSpec)*/
            case disconnect
            case tapAction
            case changeServerButtonTapped
        }
        case delegate(Delegate)
        case watchConnectionStatus
        case newConnectionStatus(VPNConnectionStatus)
    }

    private enum CancelId {
        case watchConnectionStatus
    }

    public init() { }

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

            case .newConnectionStatus(let connectionStatus):
                state.showChangeServerButton = connectionStatus != .disconnected

                @Dependency(\.serverChangeAuthorizer) var authorizer
                state.serverChangeAvailability = authorizer.serverChangeAvailability()

                return .none
            }
        }
    }
}
