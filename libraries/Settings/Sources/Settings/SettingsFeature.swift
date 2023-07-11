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

    public enum Destination: Equatable {
        case netShield
        case killSwitch
        case `protocol`
        case theme
    }

    public struct State: Equatable {
        public var destination: Destination?
        public var netShield: NetShieldSettingsFeature.State
        public var killSwitch: KillSwitchSettingsFeature.State
        public var `protocol`: ProtocolSettingsFeature.State
        public var theme: ThemeSettingsFeature.State

        public var appVersion: String = "5.0.0 (1234)"

        public init(
            destination: Destination?,
            netShield: NetShieldSettingsFeature.State,
            killSwitch: KillSwitchSettingsFeature.State,
            protocol: ProtocolSettingsFeature.State,
            theme: ThemeSettingsFeature.State
        ) {
            self.destination = destination
            self.netShield = netShield
            self.killSwitch = killSwitch
            self.protocol = `protocol`
            self.theme = theme
        }
    }

    public enum Action: Equatable {
        case dismissDestination

        case netShield(NetShieldSettingsFeature.Action)
        case killSwitch(KillSwitchSettingsFeature.Action)
        case `protocol`(ProtocolSettingsFeature.Action)
        case theme(ThemeSettingsFeature.Action)

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

    public var body: some ReducerProtocolOf<Self> {
        Scope(state: \.netShield, action: /Action.netShield) { NetShieldSettingsFeature() }
        Scope(state: \.killSwitch, action: /Action.killSwitch) { KillSwitchSettingsFeature() }
        Scope(state: \.protocol, action: /Action.protocol) { ProtocolSettingsFeature() }
        Scope(state: \.theme, action: /Action.theme) { ThemeSettingsFeature() }

        Reduce { state, action in
            switch action {
            case .netShieldTapped: state.destination = .netShield
            case .killSwitchTapped: state.destination = .killSwitch
            case .protocolTapped: state.destination = .protocol
            case .themeTapped: state.destination = .theme

            case .dismissDestination:
                state.destination = nil

            case .netShield, .killSwitch, .protocol, .theme:
                break // Child actions have already been handled by the scoped child reducers
            }
            return .none
        }
    }
}
