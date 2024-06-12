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

@Reducer
struct HomeFeature {
    @ObservableState
    struct State: Equatable {
        var protectionStatus = ProtectionStatusFeature.State()
        var countryList = CountryListFeature.State()
        var connect = ConnectFeature.State()
        @Presents var alert: AlertState<Action.Alert>?
    }

    enum Action {
        case protectionStatus(ProtectionStatusFeature.Action)
        case countryList(CountryListFeature.Action)
        case connect(ConnectFeature.Action)

        case alert(PresentationAction<Alert>)

        @CasePathable
        enum Alert {
          case errorMessage
        }
    }

    var body: some Reducer<State, Action> {
        Scope(state: \.connect, action: \.connect) {
            ConnectFeature()
        }
        Scope(state: \.protectionStatus, action: \.protectionStatus) {
            ProtectionStatusFeature()
        }
        Scope(state: \.countryList, action: \.countryList) {
            CountryListFeature()
        }
        Reduce { state, action in
            switch action {
            case .alert:
                return .none
            case .countryList(.selectItem(let item)):
                return .run { send in
                    await send(.connect(.userClickedConnect(item)))
                }
            case .countryList:
                return .none
            case .connect(.connectionFailed):
                state.alert = AlertState<Action.Alert> {
                    TextState("Connection failed")
                }
                return .none
            case .connect:
                return .none
            case .protectionStatus(.userTappedButton):
                return .run { [connectionState = state.connect.connectionState] send in
                    switch connectionState ?? .disconnected {
                    case .connected:
                        await send(.connect(.userClickedDisconnect))
                    case .connecting:
                        await send(.connect(.userClickedCancel))
                    case .disconnected:
                        await send(.connect(.userClickedConnect(nil)))
                    case .disconnecting:
                        break
                    }
                }
            case .protectionStatus:
                return .none
            }
        }
        .ifLet(\.$alert, action: \.alert)
    }
}
