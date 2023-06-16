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
import Theme

extension ColorScheme: LocalizedStringConvertible {
    var localizedDescription: String {
        switch self {
        case .auto: return Localizable.settingsThemeAuto
        case .light: return Localizable.settingsThemeLight
        case .dark: return Localizable.settingsThemeDark
        }
    }
}

public struct ThemeSettingsFeature: ReducerProtocol {
    public typealias State = ColorScheme

    public init() { }

    public enum Action: Equatable {
        case set(colorScheme: State)
    }

    public func reduce(into state: inout State, action: Action) -> EffectTask<Action> {
        switch action {
        case .set(let colorScheme):
            state = colorScheme
            return .none
        }
    }
}
