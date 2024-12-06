//
//  Created on 22/11/2024.
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
import Domain
import Ergonomics
import Theme
import SharedViews
import Home

@available(iOS 17.0, *)
struct DefaultConnectionSheet: View {
    var store: StoreOf<DefaultConnectionFeature>

    var body: some View {
        GeometryReader { _ in
            VStack(alignment: .leading, spacing: .themeSpacing24) {
                content
            }
            .safeAreaPadding(.vertical)
            .background(Color(.background))
        }
    }

    @ViewBuilder private var content: some View {
        Text("Select your default connection")
            .styled(.normal)
            .themeFont(.body2())
            .padding(.top, .themeSpacing24)
            .padding(.horizontal, .themeSpacing16)

        // Fastest, Last
        preferences(models: ConnectionPreferenceModel.staticPreferenceModels, showDividerUnderLastElement: true)

        // Recents
        dynamicPreferenceSection

        Spacer()
    }

    @ViewBuilder private var dynamicPreferenceSection: some View {
        if !store.dynamicPreferenceModels.isEmpty {
            Text("Recents")
                .styled(.weak)
                .themeFont(.body3())
                .padding(.top, .themeSpacing24)
                .padding(.horizontal, .themeSpacing16)

            preferences(models: store.dynamicPreferenceModels, showDividerUnderLastElement: false)
        }
    }

    private func preferences(models: [ConnectionPreferenceModel], showDividerUnderLastElement: Bool) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            DividedForEach(models, showDividerUnderLastElement: showDividerUnderLastElement) { model in
                WithPerceptionTracking {
                    ConnectionPreferenceView(
                        model: model,
                        isSelected: store.selection == model.preference,
                        sendAction: { store.send($0) }
                    )
                }
            }
        }
    }
}

#if DEBUG && compiler(>=6)
@available(iOS 18, *)
#Preview(traits: .dependencies {
    $0.recentsStorage = .previewValue
}) {
    let initialState = DefaultConnectionFeature.State()
    let previewStore = Store(initialState: initialState) { DefaultConnectionFeature() }
    VStack { } // Any old view that we can hook the sheet onto
        .sheet(isPresented: .constant(true)) {
            DefaultConnectionSheet(store: previewStore)
                .presentationDragIndicator(.visible)
                .presentationDetents([.medium, .large])

        }
        .preferredColorScheme(.dark)
}
#endif
