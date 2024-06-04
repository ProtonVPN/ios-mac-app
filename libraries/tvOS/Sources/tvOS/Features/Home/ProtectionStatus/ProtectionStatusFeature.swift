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
        var icon: Image?
        var title: String = "Disconnected"
        var foregroundColor: Color = Color(.text)
        var buttonTitle: String = Localizable.quickConnect

        @Shared(.inMemory("connectionState")) var connectionState: ConnectFeature.ConnectionState?
        @Shared(.inMemory("userLocation")) var userLocation: UserLocation?
    }

    enum Action {
        case userTappedButton
        case onAppear
        case connectionStateUpdated(ConnectFeature.ConnectionState?)
    }

    var body: some Reducer<State, Action> {
        Reduce { state, action in
            switch action {
            case .userTappedButton:
                return .none
            case .connectionStateUpdated(let connectionState):
                switch connectionState ?? .disconnected {
                case .connected:
                    state.icon = IconProvider.lockFilled
                    state.title = "Protected"
                    state.foregroundColor = Color(.text, .success)
                    state.buttonTitle = "Disconnect"
                case .connecting:
                    state.icon = nil
                    state.title = "Connecting"
                    state.foregroundColor = Color(.text)
                    state.buttonTitle = "Cancel"
                case .disconnected:
                    state.icon = IconProvider.lockOpenFilled
                    state.title = "Unprotected"
                    state.foregroundColor = Color(.text, .danger)
                    state.buttonTitle = Localizable.quickConnect
                case .disconnecting:
                    state.icon = nil
                    state.title = "Disconnecting"
                    state.foregroundColor = Color(.text)
                    state.buttonTitle = Localizable.quickConnect
                }
                return .none
            case .onAppear:
                return .merge(
                    .publisher { state.$connectionState.publisher.map(Action.connectionStateUpdated) },
                    .run { send in
                        @Dependency(\.userLocationService) var userLocationService
                        try? await userLocationService.updateUserLocation()
                    }
                )
            }
        }
    }
}
