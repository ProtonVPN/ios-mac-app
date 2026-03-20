//
//  Created on 20/03/2026 by Max Kupetskyi.
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
import SwiftUI
import Theme

public struct ServersFeaturesInformationView: View {
    @Bindable var store: StoreOf<ServersFeaturesInformationFeature>
    @Environment(\.dismiss) var dismiss

    public init(store: StoreOf<ServersFeaturesInformationFeature>) {
        self.store = store
    }

    public var body: some View {
        VStack(spacing: .themeSpacing0) {
            headerView

            featuresListView
        }
        .background(Color(.background))
        .onAppear { store.send(.onAppear) }
    }

    private var headerView: some View {
        Group {
            #if os(macOS)
                HStack {
                    Text(store.screenTitle)
                        .themeFont(.headline())
                        .foregroundStyle(Color(.text, .weak))
                    Spacer()
                    closeButton
                }
                .padding(.leading, .themeSpacing16)
            #else
                ZStack {
                    Text(store.screenTitle)
                        .themeFont(.body1(.bold))
                        .foregroundStyle(Color(.text))
                    HStack {
                        Spacer()
                        closeButton
                    }
                }
            #endif
        }
        .frame(height: Dimensions.topHeaderHeight)
    }

    private var closeButton: some View {
        Button(action: { dismiss() }) {
            Theme.Asset.Icons.crossBig.swiftUIImage
                .resizable()
                .frame(.square(Dimensions.closeButtonIconSize))
                .foregroundStyle(Color(.text))
                .padding(.themeSpacing16)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
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
                    if let title = sectionStore.title,
                       store.showTitles,
                       title != store.screenTitle {
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
        #if os(iOS)
            .themeFont(.body2())
        #else
            .themeFont(.headline())
        #endif
            .foregroundStyle(Color(.text, .weak))
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.leading, .themeSpacing16)
            .frame(height: Dimensions.sectionHeaderHeight)
            .listRowInsets(EdgeInsets())
    }

    public enum Dimensions {
        public static let preferredSheetWidth: CGFloat = 300
        public static let maxSheetHeight: CGFloat = 500
        public static let topHeaderHeight: CGFloat = 44
        public static let sectionHeaderHeight: CGFloat = 52
        public static let estimatedFeatureRowHeight: CGFloat = 108
        static let closeButtonIconSize: CGFloat = 12
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
