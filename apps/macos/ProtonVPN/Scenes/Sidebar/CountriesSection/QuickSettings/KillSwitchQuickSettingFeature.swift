//
//  Created on 19/03/2026 by Max Kupetskyi.
//
//  Copyright (c) 2026 Proton AG
//
//  Proton VPN is free software: you can redistribute it and/or modify
//  it under the terms of the GNU General Public License as published by
//  the Free Software Foundation, either version 3 of the License, or
//  (at your option) any later version.
//
//  Proton VPN is distributed in the hope that it will be useful,
//  but WITHOUT ANY WARRANTY; without even the implied warranty of
//  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
//  GNU General Public License for more details.
//
//  You should have received a copy of the GNU General Public License
//  along with Proton VPN.  If not, see <https://www.gnu.org/licenses/>.

import ComposableArchitecture
import SwiftUI
import Theme

@Reducer
struct KillSwitchQuickSettingFeature {
    @ObservableState
    struct State: Equatable {
        var isSelected: Bool
        @Shared(.killSwitch) var isEnabled: Bool

        var icon: Image {
            isEnabled ? Theme.Asset.Icons.switchOn.swiftUIImage : Theme.Asset.Icons.switchOff.swiftUIImage
        }

        let accessibilityIdentifier = "KillSwitchButton"
    }

    enum Action {
        case buttonTapped
        case delegate(Delegate)

        enum Delegate {
            case tapped(QuickSettingType)
        }
    }

    var body: some ReducerOf<Self> {
        Reduce { _, action in
            switch action {
            case .buttonTapped:
                .send(.delegate(.tapped(.killSwitchDisplay)))
            case .delegate:
                .none
            }
        }
    }
}
