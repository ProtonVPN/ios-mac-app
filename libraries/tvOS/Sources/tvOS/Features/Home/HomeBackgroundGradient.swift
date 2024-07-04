//
//  Created on 24/05/2024.
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

import SwiftUI
import ComposableArchitecture
import Connection

enum MainBackground: Equatable, Sendable {
    case settingsDrillDown
    case connecting
    case connected
    case disconnected
    case clear
    init(connectionState: ConnectionState?) {
        switch connectionState {
        case .disconnected:
            self = .disconnected
        case .connecting, .disconnecting, .none:
            self = .connecting
        case .connected:
            self = .connected
        }
    }
}

struct HomeBackgroundGradient: View {

    var mainBackground: MainBackground

    var color: Color {
        switch mainBackground {
        case .connected:
            return Color(.connectedGradient)
        case .disconnected:
            return Color(.disconnectedGradient)
        case .connecting:
            return Color(.connectingGradient)
        default:
            return .clear
        }
    }

    var body: some View {
        Image(.statusGradient)
            .resizable()
            .ignoresSafeArea()
            .scaledToFill()
            .foregroundStyle(color)
    }
}
