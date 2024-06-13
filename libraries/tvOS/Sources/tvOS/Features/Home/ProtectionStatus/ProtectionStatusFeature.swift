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
import Strings
import Domain

@Reducer
struct ProtectionStatusFeature {
    @ObservableState
    struct State: Equatable {

        @Shared(.inMemory("connectionState")) var connectionState: ConnectFeature.ConnectionState?
        @Shared(.inMemory("userLocation")) var userLocation: UserLocation?
    }

    enum Action {
        case userTappedButton
        case userClickedDisconnect
        case userClickedCancel
        case userClickedConnect
        case onAppear
        case connectionStateUpdated(ConnectFeature.ConnectionState?)
    }

    var body: some Reducer<State, Action> {
        Reduce { state, action in
            switch action {
            case .userTappedButton:
                return .run { [connectionState = state.connectionState] send in
                    switch connectionState ?? .disconnected {
                    case .connected:
                        await send(.userClickedDisconnect)
                    case .connecting:
                        await send(.userClickedCancel)
                    case .disconnected:
                        await send(.userClickedConnect)
                    case .disconnecting:
                        break
                    }
                }
            case .connectionStateUpdated:
                return .none
            case .onAppear:
                return .run { send in
                    @Dependency(\.userLocationService) var userLocationService
                    try? await userLocationService.updateUserLocation()
                }
            case .userClickedDisconnect:
                return .none
            case .userClickedCancel:
                return .none
            case .userClickedConnect:
                return .none
            }
        }
    }
}
