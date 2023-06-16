//
//  Created on 18/06/2023.
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
struct KillSwitchSettingsView: View {
    let store: StoreOf<KillSwitchSettingsFeature>

    var body: some View {
        WithViewStore(store, observe: { $0 }) { viewStore in
            Toggle(
                "Kill Switch",
                isOn: viewStore.binding(
                    get: { $0 == .on },
                    send: { KillSwitchSettingsFeature.Action.set(value: $0 ? .on : .off) }
                )
            )
        }
        .navigationTitle(Localizable.settingsTitleKillSwitch)
        .navigationBarTitleDisplayMode(.inline)
    }
}

struct KillSwitchSettingsView_Previews: PreviewProvider {
    static var previews: some View {
        KillSwitchSettingsView(store: Store(
            initialState: .on,
            reducer: KillSwitchSettingsFeature()
        ))
    }
}
