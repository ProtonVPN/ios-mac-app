//
//  Created on 27/05/2024.
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

import Foundation
import ComposableArchitecture
import SwiftUI

@Reducer struct ConnectFeature {
    @ObservableState
    struct State: Equatable {
        var connectionState: ConnectionState = .disconnected

        enum ConnectionState {
            case connected
            case connecting
            case disconnected
            case disconnecting
        }
    }

    enum Action {
        case userClickedConnect(HomeListItem)
        case userClickedDisconnect
        case connectionEstablished
        case connectionFailed
        case connectionTerminated
    }

    @Dependency(\.connectionClient) var client

    var body: some Reducer<State, Action> {
        Reduce { state, action in
            switch action {
            case .userClickedConnect(let item):
                withAnimation {
                    state.connectionState = .connecting
                }
                return .run { send in
                    try await client.connect(item.name)
                    await send(.connectionEstablished)
                } catch: { error, send in
                    await send(.connectionFailed)
                }
            case .userClickedDisconnect:
                withAnimation {
                    state.connectionState = .disconnecting
                }
                return .run { send in
                    try await client.disconnect()
                    await send(.connectionTerminated)
                }
            case .connectionEstablished:
                withAnimation {
                    state.connectionState = .connected
                }
                return .none
            case .connectionTerminated, .connectionFailed:
                withAnimation {
                    state.connectionState = .disconnected
                }
                return .none
            }
        }
    }
}
