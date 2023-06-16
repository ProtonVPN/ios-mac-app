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

import SwiftUI

import ComposableArchitecture

import Strings

// TODO: Nice UI according to designs
struct NetShieldSettingsView: View {
    let store: StoreOf<NetShieldSettingsFeature>

    var body: some View {
        WithViewStore(store, observe: { $0 }) { viewStore in
            Toggle(
                "NetShield",
                isOn: viewStore.binding(
                    get: { $0 == .on },
                    send: { NetShieldSettingsFeature.Action.set(value: $0 ? .on : .off) }
                )
            )
        }
        .navigationTitle(Localizable.settingsTitleNetshield)
        .navigationBarTitleDisplayMode(.inline)
    }
}

struct NetShieldSettingsView_Previews: PreviewProvider {
    static var previews: some View {
        NetShieldSettingsView(store: Store(
            initialState: .on,
            reducer: NetShieldSettingsFeature()
        ))
    }
}
