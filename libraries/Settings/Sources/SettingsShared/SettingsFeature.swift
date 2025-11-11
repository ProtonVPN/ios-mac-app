//
//  Created on 30/05/2023.
//
//  Copyright (c) 2023 Proton AG
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
import Foundation

@Reducer
public struct SettingsFeature {
    public init() {}

    @Reducer(state: .equatable)
    public enum Path {
        case netShield(NetShieldSettingsFeature)
        case killSwitch(KillSwitchSettingsFeature)
        case `protocol`(ProtocolSettingsFeature)
        case theme(ThemeSettingsFeature)
    }

    @ObservableState
    public struct State: Equatable {
        public var path = StackState<Path.State>()
        public var netShield: NetShieldSettingsFeature.State
        public var killSwitch: KillSwitchSettingsFeature.State
        public var protocolSettings: ProtocolSettingsFeature.State
        public var theme: ThemeSettingsFeature.State

        public var appVersion: String = "5.0.0 (1234)"

        public init(
            path: StackState<Path.State> = .init(),
            netShield: NetShieldSettingsFeature.State,
            killSwitch: KillSwitchSettingsFeature.State,
            protocolSettings: ProtocolSettingsFeature.State,
            theme: ThemeSettingsFeature.State
        ) {
            self.path = path
            self.netShield = netShield
            self.killSwitch = killSwitch
            self.protocolSettings = protocolSettings
            self.theme = theme
        }
    }

    @CasePathable
    public enum Action {
        case path(StackActionOf<Path>)

        // case accountTapped
        case netShieldTapped
        case killSwitchTapped
        case protocolTapped
        // case vpnAcceleratorTapped
        // case advancedTapped
        case themeTapped
        // case betaTapped
        // case widgetTapped
        // case supportTapped
        // case reportTapped
        // case logsTapped
        // case censorshipTapped
        // case rateTapped
        // case restoreDefaultSettings
        // case signOutTapped // iOS only
        // case about // MacOS only
    }

    public var body: some ReducerOf<Self> {
        Reduce { state, action in
            switch action {
            case .netShieldTapped:
                state.path.append(.netShield(state.netShield))
                return .none
            case .killSwitchTapped:
                state.path.append(.killSwitch(state.killSwitch))
                return .none
            case .protocolTapped:
                state.path.append(.protocol(state.protocolSettings))
                return .none
            case .themeTapped:
                state.path.append(.theme(state.theme))
                return .none
            case .path:
                return .none
            }
        }
        .forEach(\.path, action: \.path)
    }
}
