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
    @Reducer
    enum Path {
        case settingsDrillDown(SettingsDrillDownFeature)
        case logSelection(LogSelectionFeature)
        case logs(LogsFeature)
    }

    @ObservableState
    struct State: Equatable {
        @Shared(.userDisplayName) var userDisplayName: String?
        @Shared(.userTier) var userTier: Int?
        @Shared(.mainBackground) var mainBackground: MainBackground

        public var path = StackState<Path.State>()
        @Presents var alert: AlertState<Action.Alert>?
        var isLoading: Bool = false
    }

    enum Action {
        case alert(PresentationAction<Alert>)
        case path(StackActionOf<Path>)
        case showDrillDown(DrillDown)
        case showLogs
        case signOutSelected
        case showProgressView
        case finishSignOut
        case tabSelected

        @CasePathable
        enum Alert {
            case signOut
        }

        enum DrillDown {
            case eula
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
                if state.path.isEmpty {
                    state.$mainBackground.withLock { $0 = .clear }
                } else {
                    state.$mainBackground.withLock { $0 = .settingsDrillDown }
                }
                return .none
            case let .showDrillDown(type):
                switch type {
                case .eula:
                    state.path.append(.settingsDrillDown(.eula))
                case .contactUs:
                    state.path.append(.settingsDrillDown(.dynamic(.contactUs)))
                case .supportCenter:
                    state.path.append(.settingsDrillDown(.dynamic(.supportCenter)))
                case .privacyPolicy:
                    state.path.append(.settingsDrillDown(.dynamic(.privacyPolicy)))
                }
                state.$mainBackground.withLock { $0 = .settingsDrillDown }
                return .none
            case .showLogs:
                state.path.append(.logSelection(.init()))
                state.$mainBackground.withLock { $0 = .settingsDrillDown }
                return .none
            case let .path(.element(id: _, action: .logSelection(.logSelected(source)))):
                state.path.append(.logs(.init(logSource: source)))
                return .none
            case .signOutSelected:
                state.alert = Self.signOutAlert
                return .none
            case .alert(.presented(.signOut)):
                state.isLoading = true
                return .run { send in await send(.finishSignOut) }
            case .showProgressView:
                state.isLoading = true
                return .none
            case .finishSignOut:
                state.isLoading = false
                state.$userDisplayName.withLock { $0 = nil }
                state.$userTier.withLock { $0 = nil }
                return .none
            case .alert:
                return .none
            case .path:
                return .none
            }
        }
        .ifLet(\.$alert, action: \.alert)
        .forEach(\.path, action: \.path)
    }
}

// MARK: - Path.State Equatable Conformance

extension SettingsFeature.Path.State: Equatable {}
