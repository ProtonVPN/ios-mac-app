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
import Domain
import SwiftUI
import Theme

@Reducer
struct PortForwardingQuickSettingFeature {
    @ObservableState
    struct State: Equatable {
        var isSelected: Bool
        var isEnabled: Bool
        var isVisible: Bool
        var connectionInfo: ConnectionInfo = .portForwardingStatus(
            enabled: false,
            supportsP2P: false,
            isConnected: false
        )

        var icon: Image {
            isEnabled ? Theme.Asset.Icons.arrowsSwitch.swiftUIImage : Theme.Asset.Icons.arrowUpBounceLeft.swiftUIImage
        }

        let accessibilityIdentifier = "PortForwardingButton"
    }

    enum Action {
        case startObserving
        case updatePortForwarding

        case buttonTapped
        case delegate(Delegate)

        enum Delegate {
            case tapped(QuickSettingType)
        }
    }

    @Dependency(\.portForwardingPropertyProvider) var portForwardingPropertyProvider
    private enum CancelID { case portForwardingPropertyObservation }

    var body: some ReducerOf<Self> {
        Reduce { state, action in
            switch action {
            case .startObserving:
                state.isEnabled = portForwardingPropertyProvider.getPortForwarding() ?? false
                return .run { send in
                    for await _ in portForwardingPropertyProvider.portForwardingStream() {
                        await send(.updatePortForwarding)
                    }
                }.cancellable(id: CancelID.portForwardingPropertyObservation)
            case .updatePortForwarding:
                state.isEnabled = portForwardingPropertyProvider.getPortForwarding() ?? false
                return .none
            case .buttonTapped:
                return .send(.delegate(.tapped(.portForwardingDisplay)))
            case .delegate:
                return .none
            }
        }
    }
}
