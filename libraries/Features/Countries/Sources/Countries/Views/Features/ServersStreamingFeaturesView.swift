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

struct ServersStreamingFeaturesView: View {
    var store: StoreOf<ServersStreamingFeaturesFeature>
    @Environment(\.dismiss) var dismiss

    private let columns = Array(repeating: GridItem(.flexible(), spacing: .themeSpacing8), count: 4)

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: .themeSpacing0) {
                headerView

                featuresLabelView

                streamingContentView
            }
        }
        .background(Color(.background))
        .onAppear {
            store.send(.onAppear)
        }
    }

    var headerView: some View {
        ZStack {
            Text(Localizable.plusServers)
                .themeFont(.body1(.bold))
                .foregroundStyle(Color(.text))

            HStack {
                Button(action: { dismiss() }) {
                    IconProvider.crossBig.swiftUIImage
                        .foregroundStyle(Color(.text))
                        .frame(.square(Dimensions.closeButtonIconSize))
                        .padding(.themeSpacing4)
                }
                .padding(.leading, .themeSpacing12)

                Spacer()
            }
        }
        .frame(height: Dimensions.headerHeight)
        .padding(.top, .themeSpacing16)
    }

    var featuresLabelView: some View {
        Text(Localizable.featuresTitle)
            .themeFont(.body2())
            .foregroundStyle(Color(.text, .weak))
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, .themeSpacing16)
            .padding(.top, .themeSpacing20)
    }

    var streamingContentView: some View {
        HStack(alignment: .top, spacing: .themeSpacing8) {
            IconProvider.play.swiftUIImage
                .foregroundStyle(Color(.text))
                .frame(.square(Dimensions.playIconSize))

            VStack(alignment: .leading, spacing: .themeSpacing4) {
                streamingTitleView

                streamingDescriptionView

                streamingServicesGridView

                streamingExtraLabelView
            }
        }
        .padding(.horizontal, .themeSpacing16)
        .padding(.top, .themeSpacing12)
        .padding(.bottom, .themeSpacing20)
    }

    var streamingTitleView: some View {
        Text(Localizable.streamingTitle + " - " + store.countryName)
            .themeFont(.caption())
            .foregroundStyle(Color(.text))
    }

    var streamingDescriptionView: some View {
        Group {
            Text(Localizable.streamingServersDescription)

            Text(Localizable.streamingServersNote)
        }
        .font(.caption())
        .foregroundStyle(Color(.text, .weak))
        .fixedSize(horizontal: false, vertical: true)
    }

    var streamingServicesGridView: some View {
        LazyVGrid(columns: columns, spacing: .themeSpacing8) {
            ForEach(store.scope(state: \.streamingServices, action: \.streamingServices)) { serviceStore in
                StreamingServiceView(store: serviceStore)
                    .aspectRatio(1, contentMode: .fit)
            }
        }
        .padding(.top, .themeSpacing8)
    }

    var streamingExtraLabelView: some View {
        Text(Localizable.streamingServersExtra)
            .themeFont(.caption())
            .foregroundStyle(Color(.text, .weak))
            .padding(.top, .themeSpacing16)
    }

    private enum Dimensions {
        static let headerHeight: CGFloat = 44
        static let closeButtonIconSize: CGFloat = 24
        static let playIconSize: CGFloat = 24
    }
}

#if DEBUG
    #Preview("Three Services") {
        ServersStreamingFeaturesView(
            store: Store(initialState: .mock) {
                ServersStreamingFeaturesFeature()
            }
        )
        .preferredColorScheme(.dark)
    }

    #Preview("Single Service") {
        ServersStreamingFeaturesView(
            store: Store(initialState: .singleService) {
                ServersStreamingFeaturesFeature()
            }
        )
        .preferredColorScheme(.dark)
    }

    #Preview("Many Services") {
        ServersStreamingFeaturesView(
            store: Store(initialState: .manyServices) {
                ServersStreamingFeaturesFeature()
            }
        )
        .preferredColorScheme(.dark)
    }

    #Preview("Few Services") {
        ServersStreamingFeaturesView(
            store: Store(initialState: .fewServices) {
                ServersStreamingFeaturesFeature()
            }
        )
        .preferredColorScheme(.dark)
    }
#endif
