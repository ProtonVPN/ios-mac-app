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
import Connection
import Domain
import SwiftUI
import Theme
import VPNAppCore

@Reducer
struct KillSwitchQuickSettingFeature {
    @ObservableState
    struct State: Equatable {
        var isSelected: Bool
        @SharedReader(.killSwitchMode) var killSwitchMode: KillSwitchMode
        @SharedReader(.connectionState) var connectionState: ConnectionState

        var icon: Image {
            switch killSwitchMode {
            case .off:
                Theme.Asset.Icons.switchOff.swiftUIImage
            case .standard:
                Theme.Asset.Icons.switchOn.swiftUIImage
            case .advanced:
                Theme.Asset.Icons.switchOnLock.swiftUIImage
            }
        }

        /// Advanced KS is actively blocking (zero-peer)
        var isBlocking: Bool {
            killSwitchMode.isAdvanced && connectionState.is(\.killSwitchActive)
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
