//
//  Created on 23/12/2025 by Max Kupetskyi.
//
//  Copyright (c) 2025 Proton AG
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

import ComposableArchitecture
import CountriesShared
import SwiftUI
import Theme
import UIKit

struct ServerRow: View {
    let store: StoreOf<ServerItemFeature>
    let searchText: String?

    var body: some View {
        HStack(spacing: .themeSpacing12) {
            // Left side: Flags or content
            if store.serverType == .secureCore {
                // Secure Core mode
                secureCoreContent
            } else {
                // Regular server mode
                regularServerContent
            }

            Spacer()

            // Right side: Load indicator, feature icons, and connect button
            HStack(spacing: .themeSpacing12) {
                // Load indicator
                if !store.underMaintenance, !store.isUsersTierTooLow {
                    HStack(spacing: .themeSpacing4) {
                        Circle()
                            .fill(store.loadColor)
                            .frame(width: 8, height: 8)
                        Text("\(store.load)%")
                            .themeFont(.caption())
                            .foregroundColor(Color(.text, .weak))
                            .fixedSize()
                    }
                    .fixedSize()
                }

                // Feature icons
                HStack(spacing: .themeSpacing8) {
                    if store.isP2PAvailable {
                        Image("ic-arrows-switch", bundle: CountriesResources.bundle)
                            .resizable()
                            .aspectRatio(contentMode: .fit)
                            .frame(width: 16, height: 16)
                            .foregroundColor(.white)
                            .opacity(store.alphaOfMainElements)
                    }

                    if store.isTorAvailable {
                        Image("ic-brand-tor", bundle: CountriesResources.bundle)
                            .resizable()
                            .aspectRatio(contentMode: .fit)
                            .frame(width: 16, height: 16)
                            .foregroundColor(.white)
                            .opacity(store.alphaOfMainElements)
                    }

                    if store.isSmartAvailable {
                        Image("ic-globe", bundle: CountriesResources.bundle)
                            .resizable()
                            .aspectRatio(contentMode: .fit)
                            .frame(width: 16, height: 16)
                            .foregroundColor(.white)
                            .opacity(store.alphaOfMainElements)
                    }

                    if store.isStreamingAvailable {
                        Button(action: {
                            store.send(.streamingInfoRequested)
                        }) {
                            Image("ic-play", bundle: CountriesResources.bundle)
                                .resizable()
                                .aspectRatio(contentMode: .fit)
                                .frame(width: 16, height: 16)
                                .foregroundColor(.white)
                                .opacity(store.alphaOfMainElements)
                        }
                        .buttonStyle(PlainButtonStyle())
                    }
                }

                // Connect button
                connectButton
            }
        }
        .padding(.horizontal, .themeSpacing16)
        .padding(.vertical, .themeSpacing12)
        .background(Color.clear)
        .contentShape(Rectangle())
    }

    @ViewBuilder
    private var secureCoreContent: some View {
        HStack(spacing: .themeSpacing8) {
            // Entry flag
            if let entryFlag = store.entryCountryFlag {
                Image(uiImage: entryFlag)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .frame(width: 30, height: 20)
                    .cornerRadius(.themeRadius4)
                    .clipped()
                    .opacity(store.alphaOfMainElements)
            }

            // Chevrons
            Image("ic-chevrons-right", bundle: CountriesResources.bundle)
                .resizable()
                .aspectRatio(contentMode: .fit)
                .frame(width: 16, height: 16)
                .opacity(Double(store.alphaOfMainElements))
                .foregroundColor(Color(uiColor: .brandColor()))

            // Exit flag
            if let exitFlag = store.countryFlag {
                Image(uiImage: exitFlag)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .frame(width: 30, height: 20)
                    .cornerRadius(.themeRadius4)
                    .clipped()
                    .opacity(store.alphaOfMainElements)
            }

            // Country name
            if let searchText, !searchText.isEmpty {
                highlightedText(store.countryName, searchText: searchText)
                    .opacity(store.alphaOfMainElements)
            } else {
                Text(store.countryName)
                    .foregroundColor(Color(.text))
                    .opacity(store.alphaOfMainElements)
            }
        }
    }

    @ViewBuilder
    private var regularServerContent: some View {
        VStack(alignment: .leading, spacing: .themeSpacing2) {
            // Server name
            if let searchText, !searchText.isEmpty {
                highlightedText(store.description, searchText: searchText)
                    .opacity(store.alphaOfMainElements)
            } else {
                Text(store.description)
                    .foregroundColor(Color(.text))
                    .opacity(store.alphaOfMainElements)
            }

            // City name
            Text(store.displayCityName)
                .themeFont(.caption())
                .foregroundColor(Color(.text, .weak))
                .opacity(store.alphaOfMainElements)
        }
    }

    @ViewBuilder
    private var connectButton: some View {
        if let text = store.textInPlaceOfConnectIcon {
            // Upgrade button
            Text(text)
                .themeFont(.caption())
                .foregroundColor(Color(.text))
                .padding(.horizontal, .themeSpacing16)
                .padding(.vertical, .themeSpacing8)
                .background(store.connectButtonColor)
                .cornerRadius(.themeRadius8)
                .fixedSize()
        } else {
            // Connect button with icon
            Button(action: {
                store.send(.connectTapped)
            }) {
                ZStack {
                    Circle()
                        .foregroundStyle(store.connectButtonColor)
                        .frame(.square(36))
                    store.connectIcon.swiftUIImage
                        .aspectRatio(contentMode: .fit)
                }
            }
            .buttonStyle(PlainButtonStyle())
        }
    }
}

#if DEBUG
    #Preview("Normal") {
        ServerRow(
            store: Store(initialState: .previewNormal) {
                ServerItemFeature()
            },
            searchText: nil
        )
        .preferredColorScheme(.dark)
    }

    #Preview("Secure Core") {
        ServerRow(
            store: Store(initialState: .previewSecureCore) {
                ServerItemFeature()
            },
            searchText: nil
        )
        .preferredColorScheme(.dark)
    }

    #Preview("Secure Core with Flags") {
        ServerRow(
            store: Store(initialState: .previewSecureCoreWithFlags) {
                ServerItemFeature()
            },
            searchText: nil
        )
        .preferredColorScheme(.dark)
    }

    #Preview("Under Maintenance") {
        ServerRow(
            store: Store(initialState: .previewUnderMaintenance) {
                ServerItemFeature()
            },
            searchText: nil
        )
        .preferredColorScheme(.dark)
    }

    #Preview("Upgrade") {
        ServerRow(
            store: Store(initialState: .previewUpgrade) {
                ServerItemFeature()
            },
            searchText: nil
        )
        .preferredColorScheme(.dark)
    }

    #Preview("Streaming") {
        ServerRow(
            store: Store(initialState: .previewStreaming) {
                ServerItemFeature()
            },
            searchText: nil
        )
        .preferredColorScheme(.dark)
    }

    #Preview("High Load") {
        ServerRow(
            store: Store(initialState: .previewHighLoad) {
                ServerItemFeature()
            },
            searchText: nil
        )
        .preferredColorScheme(.dark)
    }

    #Preview("Low Load") {
        ServerRow(
            store: Store(initialState: .previewLowLoad) {
                ServerItemFeature()
            },
            searchText: nil
        )
        .preferredColorScheme(.dark)
    }

    #Preview("Translated City") {
        ServerRow(
            store: Store(initialState: .previewTranslatedCity) {
                ServerItemFeature()
            },
            searchText: nil
        )
        .preferredColorScheme(.dark)
    }

    #Preview("Search Highlight") {
        ServerRow(
            store: Store(initialState: .previewNormal) {
                ServerItemFeature()
            },
            searchText: "NY"
        )
        .preferredColorScheme(.dark)
    }
#endif
