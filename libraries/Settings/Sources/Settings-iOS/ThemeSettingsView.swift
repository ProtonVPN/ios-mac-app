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

import Settings
import Strings
import Theme

// TODO: Nice UI according to designs
struct ThemeSettingsView: View {
    let store: StoreOf<ThemeSettingsFeature>

    struct OptionModel: Identifiable {
        let id = UUID()

        let colorScheme: Theme.ColorScheme
        let asset: ImageAsset
    }

    let options = [
        OptionModel(colorScheme: .light, asset: Asset.themeLight),
        OptionModel(colorScheme: .dark, asset: Asset.themeDark),
        OptionModel(colorScheme: .auto, asset: Asset.themeAuto)
    ]

    var body: some View {
        WithViewStore(store, observe: { $0 }) { viewStore in
            HStack(alignment: .top, spacing: .themeSpacing32) {
                ForEach(options) { option in
                    colorSchemeOptionControl(
                        model: option,
                        currentValue: viewStore.binding(get: { $0 }, send: ThemeSettingsFeature.Action.set)
                    )
                }
            }
        }
        .navigationTitle(Localizable.settingsTitleTheme)
        .navigationBarTitleDisplayMode(.inline)
    }

    private func colorSchemeOptionControl(model: OptionModel, currentValue: Binding<Theme.ColorScheme>) -> some View {
        Button(action: { currentValue.wrappedValue = model.colorScheme }) {
            VStack(alignment: .center, spacing: .themeSpacing16) {
                Image(asset: model.asset)
                    .renderingMode(.original)
                Text(model.colorScheme.localizedDescription)
                    .themeFont(.body2())
                    .foregroundColor(Color(.text, .normal))
                Accessory(style: .checkmark(isActive: currentValue.wrappedValue == model.colorScheme))

            }
        }.onTapGesture { currentValue.wrappedValue = model.colorScheme }
    }
}

struct ThemeSettingsView_Previews: PreviewProvider {
    static var previews: some View {
        ThemeSettingsView(store: StoreOf<ThemeSettingsFeature>(
            initialState: .light,
            reducer: ThemeSettingsFeature()
        ))
    }
}
