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
    let onDismiss: () -> Void

    var body: some View {
        VStack(spacing: 0) {
            // Header with title and close button
            ZStack {
                Text(Localizable.informationTitle)
                    .font(.system(size: 17, weight: .bold))
                    .foregroundColor(.white)

                HStack {
                    Button(action: onDismiss) {
                        Image(uiImage: IconProvider.crossBig)
                            .foregroundColor(.white)
                            .frame(width: 24, height: 24)
                            .padding(3)
                    }
                    .padding(.leading, .themeSpacing12)

                    Spacer()
                }
            }
            .frame(height: 44)
            .padding(.top, .themeSpacing8)

            // Features list
            List {
                ForEach(store.scope(state: \.sections, action: \.sections)) { sectionStore in
                    Section {
                        ForEach(sectionStore.scope(state: \.features, action: \.features)) { featureStore in
                            FeatureRow(store: featureStore)
                                .listRowInsets(EdgeInsets())
                                .listRowSeparator(.hidden)
                        }
                    } header: {
                        if let title = sectionStore.title, store.showTitles {
                            Text(title)
                                .themeFont(.body2(emphasised: false))
                                .foregroundColor(Color(.text, .weak))
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .padding(.leading, .themeSpacing16)
                                .frame(height: Dimensions.headerHeight)
                                .listRowInsets(EdgeInsets())
                                .background(Color(uiColor: .backgroundColor()))
                        }
                    }
                }
            }
            .listStyle(.plain)
            .background(Color(.background))
        }
        .background(Color(.background))
        .onAppear {
            store.send(.onAppear)
        }
    }

    private enum Dimensions {
        static let headerHeight: CGFloat = 52
    }
}

#if DEBUG
    #Preview("All Features") {
        ServersFeaturesInformationView(
            store: Store(initialState: .mock) {
                ServersFeaturesInformationFeature()
            },
            onDismiss: {}
        )
        .preferredColorScheme(.dark)
    }

    #Preview("Multiple Sections") {
        ServersFeaturesInformationView(
            store: Store(initialState: .multipleSections) {
                ServersFeaturesInformationFeature()
            },
            onDismiss: {}
        )
        .preferredColorScheme(.dark)
    }

    #Preview("No Titles") {
        ServersFeaturesInformationView(
            store: Store(initialState: .noTitles) {
                ServersFeaturesInformationFeature()
            },
            onDismiss: {}
        )
        .preferredColorScheme(.dark)
    }

    #Preview("Single Feature") {
        ServersFeaturesInformationView(
            store: Store(initialState: .singleFeature) {
                ServersFeaturesInformationFeature()
            },
            onDismiss: {}
        )
        .preferredColorScheme(.dark)
    }
#endif
