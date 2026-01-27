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

import LegacyCommon
import ProtonCoreUIFoundations
import Strings
import SwiftUI
import Theme

struct ServersStreamingFeaturesView: View {
    let viewModel: ServersStreamingFeaturesViewModel
    let onDismiss: () -> Void

    private let columns = Array(repeating: GridItem(.flexible(), spacing: .themeSpacing8), count: 4)

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                // Header with title and close button
                ZStack {
                    Text(Localizable.plusServers)
                        .font(.system(size: 17, weight: .bold))
                        .foregroundColor(.white)

                    HStack {
                        Button(action: onDismiss) {
                            Image(uiImage: IconProvider.crossBig)
                                .foregroundColor(.white)
                                .frame(width: 24, height: 24)
                                .padding(.themeSpacing4)
                        }
                        .padding(.leading, .themeSpacing12)

                        Spacer()
                    }
                }
                .frame(height: 44)
                .padding(.top, .themeSpacing16)

                // Features label
                Text(Localizable.featuresTitle)
                    .font(.system(size: 15))
                    .foregroundColor(Color(.text, .weak))
                    .frame(height: 30)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, .themeSpacing16)
                    .padding(.top, .themeSpacing20)

                // Content with icon alignment
                HStack(alignment: .top, spacing: .themeSpacing8) {
                    Image(uiImage: IconProvider.play)
                        .foregroundColor(.white)
                        .frame(width: 24, height: 24)

                    VStack(alignment: .leading, spacing: .themeSpacing4) {
                        Text(Localizable.streamingTitle + " - " + viewModel.countryName)
                            .font(.system(size: 14))
                            .foregroundColor(.white)

                        Text(Localizable.streamingServersDescription)
                            .font(.system(size: 13))
                            .foregroundColor(Color(.text, .weak))
                            .fixedSize(horizontal: false, vertical: true)

                        Text(Localizable.streamingServersNote)
                            .font(.system(size: 13))
                            .foregroundColor(Color(.text, .weak))
                            .fixedSize(horizontal: false, vertical: true)

                        // Services grid
                        LazyVGrid(columns: columns, spacing: .themeSpacing8) {
                            ForEach(0 ..< viewModel.totalItems, id: \.self) { index in
                                StreamingServiceItem(service: viewModel.vpnOption(for: index))
                                    .aspectRatio(1, contentMode: .fit)
                            }
                        }
                        .padding(.top, .themeSpacing8)

                        // Extra label
                        Text(Localizable.streamingServersExtra)
                            .font(.system(size: 13))
                            .foregroundColor(Color(.text, .weak))
                            .padding(.top, .themeSpacing16)
                    }
                }
                .padding(.horizontal, .themeSpacing16)
                .padding(.top, .themeSpacing12)
                .padding(.bottom, .themeSpacing20)
            }
        }
        .background(Color(uiColor: .backgroundColor()))
    }
}

#if DEBUG
    #Preview("Three Services") {
        ServersStreamingFeaturesView(viewModel: ServersStreamingFeaturesViewModelImplementation.mock, onDismiss: {})
            .preferredColorScheme(.dark)
    }

    #Preview("Single Service") {
        ServersStreamingFeaturesView(viewModel: ServersStreamingFeaturesViewModelImplementation.singleService, onDismiss: {})
            .preferredColorScheme(.dark)
    }

    #Preview("Many Services") {
        ServersStreamingFeaturesView(viewModel: ServersStreamingFeaturesViewModelImplementation.manyServices, onDismiss: {})
            .preferredColorScheme(.dark)
    }

    #Preview("Few Services") {
        ServersStreamingFeaturesView(viewModel: ServersStreamingFeaturesViewModelImplementation.fewServices, onDismiss: {})
            .preferredColorScheme(.dark)
    }
#endif
