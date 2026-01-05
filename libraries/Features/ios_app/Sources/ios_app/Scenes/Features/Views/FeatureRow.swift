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

import Dependencies
import Domain
import LegacyCommon
import ProtonCoreUIFoundations
import Strings
import SwiftUI
import Theme
import VPNAppCore

struct FeatureRow: View {
    let viewModel: FeatureCellViewModel

    var body: some View {
        VStack(alignment: .leading, spacing: .themeSpacing8) {
            // Top: Icon + Title
            HStack(spacing: .themeSpacing8) {
                iconView
                    .frame(width: 24, height: 24)

                Text(viewModel.title)
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundColor(.white)
            }

            // Bottom: Spacer + Content
            HStack(alignment: .top, spacing: .themeSpacing8) {
                // Dummy spacer to match icon width
                Color.clear
                    .frame(width: 24, height: 24)

                VStack(alignment: .leading, spacing: .themeSpacing8) {
                    Text(viewModel.description)
                        .font(.system(size: 13))
                        .foregroundColor(Color(.text, .weak))
                        .fixedSize(horizontal: false, vertical: true)

                    if viewModel.displayLoads {
                        loadIndicatorsView
                    }

                    if let urlContact = viewModel.urlContact {
                        learnMoreButton(url: urlContact)
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
        switch viewModel.icon {
        case let .image(image):
            Image(uiImage: image)
                .resizable()
                .aspectRatio(contentMode: .fit)
                .foregroundColor(.white)

        case let .url(url):
            if let url {
                AsyncImage(url: url) { image in
                    image
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                } placeholder: {
                    Color.clear
                }
            } else {
                Color.clear
            }
        }
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

    private func learnMoreButton(url: VPNLink) -> some View {
        Button(action: {
            @Dependency(\.linkOpener) var linkOpener
            linkOpener.open(url)
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
    FeatureRow(viewModel: SmartRoutingFeatureCellViewModel())
        .preferredColorScheme(.dark)
}

#Preview("Streaming") {
    FeatureRow(viewModel: StreamingFeatureCellViewModel())
        .preferredColorScheme(.dark)
}

#Preview("P2P") {
    FeatureRow(viewModel: P2PFeatureCellViewModel())
        .preferredColorScheme(.dark)
}

#Preview("Tor") {
    FeatureRow(viewModel: TorFeatureCellViewModel())
        .preferredColorScheme(.dark)
}

#Preview("Load Performance") {
    FeatureRow(viewModel: LoadPerformanceFeatureCellViewModel())
        .preferredColorScheme(.dark)
}

#Preview("Free Servers") {
    FeatureRow(viewModel: FreeServersFeatureCellViewModel())
        .preferredColorScheme(.dark)
}

#Preview("Gateway") {
    FeatureRow(viewModel: GatewayFeatureCellViewModel())
        .preferredColorScheme(.dark)
}
