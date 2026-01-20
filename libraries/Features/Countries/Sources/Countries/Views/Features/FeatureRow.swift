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
import Dependencies
import Domain
import LegacyCommon
import ProtonCoreUIFoundations
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
                    .frame(width: 24, height: 24)

                Text(store.title)
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundColor(.white)
            }

            // Bottom: Spacer + Content
            HStack(alignment: .top, spacing: .themeSpacing8) {
                // Dummy spacer to match icon width
                Color.clear
                    .frame(width: 24, height: 24)

                VStack(alignment: .leading, spacing: .themeSpacing8) {
                    Text(store.description)
                        .font(.system(size: 13))
                        .foregroundColor(Color(.text, .weak))
                        .fixedSize(horizontal: false, vertical: true)

                    if store.displayLoads {
                        loadIndicatorsView
                    }

                    if store.hasLearnMore {
                        learnMoreButton()
                    }
                }
            }
        }
        .padding(.horizontal, .themeSpacing16)
        .padding(.bottom, .themeSpacing16)
        .background(Color(uiColor: .backgroundColor()))
    }

    @ViewBuilder
    private var iconView: some View {
        Image(uiImage: store.icon)
            .resizable()
            .aspectRatio(contentMode: .fit)
            .foregroundColor(.white)
    }

    private var loadIndicatorsView: some View {
        HStack(spacing: .themeSpacing16) {
            LoadIndicator(
                color: Color(uiColor: .notificationOKColor()),
                text: Localizable.performanceLoadLow
            )

            LoadIndicator(
                color: Color(uiColor: .notificationWarningColor()),
                text: Localizable.performanceLoadMedium
            )

            LoadIndicator(
                color: Color(uiColor: .notificationErrorColor()),
                text: Localizable.performanceLoadHigh
            )
        }
    }

    private func learnMoreButton() -> some View {
        Button(action: {
            store.send(.learnMoreTapped)
        }) {
            HStack(spacing: .themeSpacing8) {
                Text(Localizable.learnMore)
                    .font(.system(size: 15))

                Image(uiImage: IconProvider.arrowOutSquare)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(width: 16, height: 16)
            }
            .foregroundColor(Color(uiColor: .textAccent()))
        }
    }
}

struct LoadIndicator: View {
    let color: Color
    let text: String

    var body: some View {
        HStack(spacing: .themeSpacing8) {
            Circle()
                .fill(color)
                .frame(width: 8, height: 8)

            Text(text)
                .font(.system(size: 13))
                .foregroundColor(Color(.text, .weak))
        }
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
