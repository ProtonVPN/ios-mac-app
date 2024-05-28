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

struct CountriesListBackgroundGradient: View {

    @Bindable var store: StoreOf<MainFeature>

    var color: Color {
        switch store.connect.connectionState {
        case .connected:
            return Color(.connectedGradient)
        case .disconnected:
            return Color(.disconnectedGradient)
        case .connecting, .disconnecting:
            return Color(.connectingGradient)
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
