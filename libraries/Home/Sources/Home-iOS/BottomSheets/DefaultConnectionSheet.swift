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

import Collections
import ComposableArchitecture
import ConnectionInventory
import Domain
import Ergonomics
import HomeShared
import Strings
import SwiftUI
import Theme

extension View {
    @ViewBuilder
    func padSafeArea() -> some View {
        if #available(iOS 17.0, *) {
            self.safeAreaPadding(.vertical)
        } else {
            self
        }
    }
}

struct DefaultConnectionSheet: View {
    private static let sectionHeaderHeight: CGFloat = 52.0
    var store: StoreOf<DefaultConnectionFeature>

    var body: some View {
        WithPerceptionTracking {
            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    content
                }
                .padSafeArea()
            }
            .background(Color(.background))
        }
    }

    @ViewBuilder private var content: some View {
        section {
            Text(Localizable.homeDefaultConnectionTitle)
                .styled(.normal)
                .themeFont(.body2())
        } content: {
            // Fastest, Last
            preferences(models: ConnectionPreferenceModel.staticPreferenceModels, showDividerUnderLastElement: true)
        }

        if !store.dynamicPreferenceModels.isEmpty {
            section {
                Text(Localizable.homeRecentsRecentSection)
                    .styled(.weak)
                    .themeFont(.body3())
            } content: {
                // Recents
                preferences(models: store.dynamicPreferenceModels, showDividerUnderLastElement: false)
            }
        }
        Spacer()
    }

    private func preferences(models: [ConnectionPreferenceModel], showDividerUnderLastElement: Bool) -> some View {
        DividedForEach(models, showDividerUnderLastElement: showDividerUnderLastElement) { model in
            WithPerceptionTracking {
                ConnectionPreferenceView(
                    model: model,
                    isSelected: store.defaultConnectionPreference == model.preference,
                    sendAction: { store.send($0) }
                )
            }
        }
    }

    @ViewBuilder private func section(
        title: @escaping () -> some View,
        content: @escaping () -> some View
    ) -> some View {
        sectionHeader(title: title)
        content()
    }

    @ViewBuilder private func sectionHeader(title: () -> some View) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            Spacer()
            title()
                .padding(.horizontal, .themeSpacing16)
                .padding(.bottom, .themeSpacing8)
        }
        .frame(height: Self.sectionHeaderHeight)
    }
}

#if DEBUG

    #Preview {
        ZStack { // Xcode 15: #Preview macro only supports a single View in its body
            @Shared(.recents) var recents: OrderedSet<RecentConnection> = [
                .pinnedFastest,
                .connectionRegion,
                .connectionSecureCoreFastest
            ]
            let previewStore = Store(initialState: .init()) { DefaultConnectionFeature() }
            VStack {} // Any old view that we can hook the sheet onto
                .sheet(isPresented: .constant(true)) {
                    DefaultConnectionSheet(store: previewStore)
                        .presentationDragIndicator(.visible)
                        .presentationDetents([.medium, .large])
                }
                .preferredColorScheme(.dark)
        }
    }
#endif
