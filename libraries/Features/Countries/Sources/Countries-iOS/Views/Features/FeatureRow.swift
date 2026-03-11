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
import CountriesShared
import Dependencies
import Domain
import LegacyCommon
import Strings
import SwiftUI
import Theme
import VPNAppCore

struct FeatureRow: View {
    let store: StoreOf<ServerFeatureItem>

    var body: some View {
        VStack(alignment: .leading, spacing: .themeSpacing8) {
            // Top: Icon + Title
            HStack(spacing: .themeSpacing8) {
                iconView
                    .frame(.square(Dimensions.iconSize))

                Text(store.title)
                    .themeFont(.body2(emphasised: true))
                    .foregroundColor(Color(.text))

                Spacer()
            }

            // Bottom: Spacer + Content
            HStack(alignment: .top, spacing: .themeSpacing8) {
                // Dummy spacer to match icon width
                Color.clear
                    .frame(.square(Dimensions.iconSize))

                VStack(alignment: .leading, spacing: .themeSpacing8) {
                    Text(store.description)
                        .themeFont(.caption())
                        .foregroundColor(Color(.text, .weak))
                        .fixedSize(horizontal: false, vertical: true)

                    if store.displayLoads {
                        loadIndicatorsView
                    }

                    if store.hasLearnMore {
                        learnMoreButton
                    }
                }

                Spacer()
            }
        }
        .padding(.horizontal, .themeSpacing16)
        .padding(.bottom, .themeSpacing16)
        .background(Color(.background))
    }

    @ViewBuilder
    private var iconView: some View {
        store.icon.swiftUIImage
            .resizable()
            .aspectRatio(contentMode: .fit)
            .foregroundColor(Color(.text))
    }

    private var loadIndicatorsView: some View {
        HStack(spacing: .themeSpacing16) {
            LoadIndicator(
                color: Color(.icon, .success),
                text: Localizable.performanceLoadLow
            )

            LoadIndicator(
                color: Color(.icon, .warning),
                text: Localizable.performanceLoadMedium
            )

            LoadIndicator(
                color: Color(.icon, .danger),
                text: Localizable.performanceLoadHigh
            )
        }
    }

    private var learnMoreButton: some View {
        Button(action: {
            store.send(.learnMoreTapped)
        }) {
            HStack(spacing: .themeSpacing8) {
                Text(Localizable.learnMore)
                    .themeFont(.body2())

                Theme.Asset.Icons.arrowOutSquare.swiftUIImage
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(.square(Dimensions.learnMoreIconSize))
            }
            .foregroundColor(Color(.text, .interactive))
        }
    }

    private enum Dimensions {
        static let iconSize: CGFloat = 24
        static let learnMoreIconSize: CGFloat = 16
    }
}

struct LoadIndicator: View {
    let color: Color
    let text: String

    var body: some View {
        HStack(spacing: .themeSpacing8) {
            Circle()
                .fill(color)
                .frame(.square(Dimensions.loadIndicatorCircleSize))

            Text(text)
                .themeFont(.caption())
                .foregroundColor(Color(.text, .weak))
        }
    }

    private enum Dimensions {
        static let loadIndicatorCircleSize: CGFloat = 8
    }
}

#Preview("Smart Routing") {
    FeatureRow(store: .init(initialState: ServerFeatureItem.State(featureType: .smartRouting), reducer: {
        ServerFeatureItem()
    }))
    .preferredColorScheme(.dark)
}

#Preview("Streaming") {
    FeatureRow(store: .init(initialState: ServerFeatureItem.State(featureType: .streaming), reducer: {
        ServerFeatureItem()
    }))
    .preferredColorScheme(.dark)
}

#Preview("P2P") {
    FeatureRow(store: .init(initialState: ServerFeatureItem.State(featureType: .p2p), reducer: {
        ServerFeatureItem()
    }))
    .preferredColorScheme(.dark)
}

#Preview("Tor") {
    FeatureRow(store: .init(initialState: ServerFeatureItem.State(featureType: .tor), reducer: {
        ServerFeatureItem()
    }))
    .preferredColorScheme(.dark)
}

#Preview("Load Performance") {
    FeatureRow(store: .init(initialState: ServerFeatureItem.State(featureType: .loadPerformance), reducer: {
        ServerFeatureItem()
    }))
    .preferredColorScheme(.dark)
}

#Preview("Free Servers") {
    FeatureRow(store: .init(initialState: ServerFeatureItem.State(featureType: .freeServers), reducer: {
        ServerFeatureItem()
    }))
    .preferredColorScheme(.dark)
}

#Preview("Gateway") {
    FeatureRow(store: .init(initialState: ServerFeatureItem.State(featureType: .gateway), reducer: {
        ServerFeatureItem()
    }))
    .preferredColorScheme(.dark)
}
