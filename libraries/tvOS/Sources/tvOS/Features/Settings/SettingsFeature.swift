//
//  Created on 25/04/2024.
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

@Reducer
struct SettingsFeature {
    @Reducer(state: .equatable)
    enum Destination {
        case settingsDrillDown(SettingsDrillDownFeature)
    }

    @ObservableState
    struct State: Equatable {
        @Shared(.userDisplayName) var userDisplayName: String?
        @Shared(.userTier) var userTier: Int?
        @Shared(.mainBackground) var mainBackground: MainBackground = .clear

        @Presents var destination: Destination.State?
        @Presents var alert: AlertState<Action.Alert>?
        var isLoading: Bool = false
    }

    @CasePathable
    enum Action {
        case alert(PresentationAction<Alert>)
        case destination(PresentationAction<Destination.Action>)
        case showDrillDown(DrillDown)
        case signOutSelected
        case showProgressView
        case finishSignOut
        case tabSelected

        @CasePathable
        enum Alert {
          case signOut
        }

        enum DrillDown {
            case contactUs
            case supportCenter
            case privacyPolicy
        }
    }

    static let signOutAlert = AlertState<Action.Alert> {
        TextState("Sign out")
    } actions: {
        ButtonState(role: .destructive, action: .signOut) {
            TextState("Sign out")
        }
        ButtonState(role: .cancel) {
            TextState("Cancel")
        }
    } message: {
        TextState("Are you sure you want to sign out of Proton VPN?")
    }

    var body: some Reducer<State, Action> {
        Reduce { state, action in
            switch action {
            case .tabSelected:
                if state.destination == nil {
                    state.mainBackground = .clear
                } else {
                    state.mainBackground = .settingsDrillDown
                }
                return .none
            case .showDrillDown(let type):
                switch type {
                case .contactUs:
                    state.destination = .settingsDrillDown(.contactUs)
                case .supportCenter:
                    state.destination = .settingsDrillDown(.supportCenter)
                case .privacyPolicy:
                    state.destination = .settingsDrillDown(.privacyPolicy)
                }
                state.mainBackground = .settingsDrillDown
                return .none
            case .signOutSelected:
                state.alert = Self.signOutAlert
                return .none
            case .alert(.presented(.signOut)):
                state.isLoading = true
                return .run { send in await send(.finishSignOut) }
            case .alert:
                return .none
            case .destination:
                return .none
            case .finishSignOut:
                state.isLoading = false
                state.userDisplayName = nil
                state.userTier = nil
                return .none
            case .showProgressView:
                state.isLoading = true
                return .none
            }
        }
        .ifLet(\.$alert, action: \.alert)
        .ifLet(\.$destination, action: \.destination)
    }
}
