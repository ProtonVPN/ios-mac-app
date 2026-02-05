//
//  Created on 23/12/2025 by Max Kupetskyi.
//
//  Copyright (c) 2025 Proton AG
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
import LegacyCommon
import ProtonCoreUIFoundations
import Strings
import SwiftUI
import Theme

struct ServersFeaturesInformationView: View {
    @Bindable var store: StoreOf<ServersFeaturesInformationFeature>
    @Environment(\.dismiss) var dismiss

    var body: some View {
        VStack(spacing: .themeSpacing0) {
            headerView

            featuresListView
        }
        .background(Color(.background))
        .onAppear {
            store.send(.onAppear)
        }
    }

    private var headerView: some View {
        ZStack {
            Text(Localizable.informationTitle)
                .themeFont(.body1(.bold))
                .foregroundStyle(Color(.text))

            HStack {
                closeButton

                Spacer()
            }
        }
        .frame(height: Dimensions.topHeaderHeight)
        .padding(.top, .themeSpacing8)
    }

    private var closeButton: some View {
        Button(action: { dismiss() }) {
            IconProvider.crossBig.swiftUIImage
                .foregroundStyle(Color(.text))
                .frame(.square(Dimensions.closeButtonIconSize))
                .padding(.themeSpacing4)
        }
        .padding(.leading, .themeSpacing12)
    }

    private var featuresListView: some View {
        List {
            ForEach(store.scope(state: \.sections, action: \.sections)) { sectionStore in
                Section {
                    ForEach(sectionStore.scope(state: \.features, action: \.features)) { featureStore in
                        FeatureRow(store: featureStore)
                            .listRowInsets(EdgeInsets())
                            .listRowSeparator(.hidden)
                            .listRowBackground(Color(.background))
                    }
                } header: {
                    if let title = sectionStore.title, store.showTitles {
                        sectionHeaderView(title: title)
                    }
                }
            }
        }
        .listStyle(.plain)
        .scrollContentBackground(.hidden)
    }

    func sectionHeaderView(title: String) -> some View {
        Text(title)
            .themeFont(.body2(emphasised: false))
            .foregroundStyle(Color(.text, .weak))
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.leading, .themeSpacing16)
            .frame(height: Dimensions.headerHeight)
            .listRowInsets(EdgeInsets())
    }

    private enum Dimensions {
        static let headerHeight: CGFloat = 52
        static let topHeaderHeight: CGFloat = 44
        static let closeButtonIconSize: CGFloat = 24
    }
}

#if DEBUG
    #Preview("All Features") {
        ServersFeaturesInformationView(
            store: Store(initialState: .mock) {
                ServersFeaturesInformationFeature()
            }
        )
        .preferredColorScheme(.dark)
    }

    #Preview("Multiple Sections") {
        ServersFeaturesInformationView(
            store: Store(initialState: .multipleSections) {
                ServersFeaturesInformationFeature()
            }
        )
        .preferredColorScheme(.dark)
    }

    #Preview("No Titles") {
        ServersFeaturesInformationView(
            store: Store(initialState: .noTitles) {
                ServersFeaturesInformationFeature()
            }
        )
        .preferredColorScheme(.dark)
    }

    #Preview("Single Feature") {
        ServersFeaturesInformationView(
            store: Store(initialState: .singleFeature) {
                ServersFeaturesInformationFeature()
            }
        )
        .preferredColorScheme(.dark)
    }
#endif
