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
        @SharedReader(.defaultConnection) public var defaultConnection: ConnectionSpec
        public var changeServerAllowedDate: Date = Date.now + 10

        public init() { }

        public var presentedSpec: ConnectionSpec {
            switch vpnConnectionStatus {
            case .disconnected:
                return defaultConnection
            case .connected(let connectionSpec, _),
                    .connecting(let connectionSpec, _),
                    .loadingConnectionInfo(let connectionSpec, _),
                    .disconnecting(let connectionSpec, _):
                return connectionSpec
            }
        }
    }

    public enum Action: Equatable {
        case connect(ConnectionSpec)
        case disconnect
        case tapAction
        case changeServerButtonTapped
    }

    public init() { }

    public var body: some Reducer<State, Action> {
        Reduce { state, action in
            switch action {
            case .connect:
                return .none
            case .disconnect:
                return .none
            case .tapAction:
                return .none
            case .changeServerButtonTapped:
                return .none
            }
        }
    }
}
