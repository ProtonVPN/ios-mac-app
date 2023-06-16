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

import Foundation

import ComposableArchitecture

public struct SettingsFeature: ReducerProtocol {

    public init() { }

    public struct State: Equatable {
        @PresentationState var destination: Destination.State?
        var netShield: NetShieldSettingsFeature.State
        var killSwitch: KillSwitchSettingsFeature.State
        var theme: ThemeSettingsFeature.State

        var appVersion: String = "5.0.0 (1234)"

        public init(
            destination: Destination.State?,
            netShield: NetShieldSettingsFeature.State,
            killSwitch: KillSwitchSettingsFeature.State,
            theme: ThemeSettingsFeature.State
        ) {
            self.destination = destination
            self.netShield = netShield
            self.killSwitch = killSwitch
            self.theme = theme
        }
    }

    public enum Action: Equatable {
        case destination(PresentationAction<Destination.Action>)

        // case accountTapped
        case netShieldTapped
        case killSwitchTapped
        // case vpnProtocolTapped
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

    public var body: some ReducerProtocolOf<Self> {
        Reduce { state, action in
            switch action {
            case .netShieldTapped:
                state.destination = .netShield(state.netShield)
            case .killSwitchTapped:
                state.destination = .killSwitch(state.killSwitch)
            case .themeTapped:
                state.destination = .theme(state.theme)

            case let .destination(.presented(.netShield(.set(active)))):
                state.netShield = active
            case let .destination(.presented(.killSwitch(.set(active)))):
                state.killSwitch = active
            case let .destination(.presented(.theme(.set(theme)))):
                state.theme = theme

            case .destination(.dismiss):
                break
            }
            return .none
        }
        .ifLet(\.$destination, action: /Action.destination) { Destination() } // child presentation reducer
    }
}

extension SettingsFeature {
    public struct Destination: ReducerProtocol {
        public enum State: Equatable {
            case netShield(NetShieldSettingsFeature.State)
            case killSwitch(KillSwitchSettingsFeature.State)
            case theme(ThemeSettingsFeature.State)
        }
        public enum Action: Equatable {
            case netShield(NetShieldSettingsFeature.Action)
            case killSwitch(KillSwitchSettingsFeature.Action)
            case theme(ThemeSettingsFeature.Action)
        }
        public var body: some ReducerProtocolOf<Self> {
            Scope(state:  /State.netShield, action: /Action.netShield) { NetShieldSettingsFeature() }
            Scope(state:  /State.killSwitch, action: /Action.killSwitch) { KillSwitchSettingsFeature() }
            Scope(state: /State.theme, action: /Action.theme) { ThemeSettingsFeature() }
        }
    }
}
