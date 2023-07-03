//
//  Created on 13/06/2023.
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

import Strings

public enum NetShieldType: LocalizedStringConvertible {
    case on
    case off

    var localizedDescription: String {
        switch self {
        case .on: return Localizable.settingsNetshieldOn
        case .off: return Localizable.settingsNetshieldOff
        }
    }
}

public struct NetShieldSettingsFeature: ReducerProtocol {
    public typealias State = NetShieldType

    public enum Action: Equatable {
        case set(value: NetShieldType)
    }

    public func reduce(into state: inout State, action: Action) -> EffectTask<Action> {
        switch action {
        case let .set(value):
            state = value
            return .none
        }
    }
}
