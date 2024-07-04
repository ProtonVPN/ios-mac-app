//
//  Created on 04/06/2024.
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
import SwiftUI
import ProtonCoreUIFoundations
import Domain
import Connection

@Reducer
struct ProtectionStatusFeature {
    @ObservableState
    struct State: Equatable {

        @Shared(.connectionState) var connectionState: ConnectionState?
        @Shared(.userLocation) var userLocation: UserLocation?
    }

    enum Action {
        case userTappedButton
        case onAppear
        case delegate(Delegate)

        @CasePathable
        enum Delegate: Equatable {
            case userClickedDisconnect
            case userClickedCancel
            case userClickedConnect
        }
    }

    var body: some Reducer<State, Action> {
        Reduce { state, action in
            switch action {
            case .userTappedButton:
                return .run { [connectionState = state.connectionState] send in
                    switch connectionState ?? .disconnected(nil) {
                    case .connected:
                        await send(.delegate(.userClickedDisconnect))
                    case .connecting:
                        await send(.delegate(.userClickedCancel))
                    case .disconnected:
                        await send(.delegate(.userClickedConnect))
                    case .disconnecting:
                        break
                    }
                }
            case .onAppear:
                return .run { send in
                    @Dependency(\.userLocationService) var userLocationService
                    try? await userLocationService.updateUserLocation()
                }
            case .delegate:
                return .none
            }
        }
    }
}
