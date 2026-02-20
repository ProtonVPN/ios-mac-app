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

struct CountryRow: View {
    let store: StoreOf<CountryFeature>
    let searchText: String?

    var body: some View {
        HStack(spacing: .themeSpacing12) {
            // Flag(s) and country name
            leadingContent

            Spacer()

            if store.showFeatureIcons {
                // Feature icons on the right
                featureIcons
            }

            // Connect button (if enabled)
            if store.showCountryConnectButton {
                connectButton
            }

            // Chevron (hidden only when showing upgrade text)
            if store.textInPlaceOfConnectIcon == nil {
                chevronIcon
            }
        }
        .padding(.horizontal, .themeSpacing16)
        .padding(.vertical, .themeSpacing12)
        .background(Color.clear)
        .contentShape(Rectangle())
    }

    // MARK: - Subviews

    @ViewBuilder
    private var leadingContent: some View {
        HStack(spacing: store.isSecureCoreCountry ? .themeSpacing8 : .themeSpacing16) {
            if store.isSecureCoreCountry {
                secureCoreIcon
            }

            if let flagImage = store.flag {
                flagView(flagImage)
            }

            countryNameText
        }
    }

    @ViewBuilder
    private var secureCoreIcon: some View {
        Image("ic-chevrons-right", bundle: CountriesResources.bundle)
            .resizable()
            .aspectRatio(contentMode: .fit)
            .frame(width: 16, height: 16)
            .foregroundColor(Color(uiColor: .brandColor()))
    }

    @ViewBuilder
    private func flagView(_ flagImage: UIImage) -> some View {
        Image(uiImage: flagImage)
            .resizable()
            .aspectRatio(contentMode: .fill)
            .frame(width: 30, height: 20)
            .cornerRadius(store.isGateway ? 0 : .themeRadius4)
            .clipped()
            .opacity(store.alphaOfMainElements)
    }

    @ViewBuilder
    private var countryNameText: some View {
        if let searchText, !searchText.isEmpty {
            highlightedText(store.description, searchText: searchText)
                .opacity(Double(store.alphaOfMainElements))
        } else {
            Text(store.description)
                .foregroundColor(Color(.text))
                .opacity(store.alphaOfMainElements)
        }
    }

    @ViewBuilder
    private var featureIcons: some View {
        HStack(spacing: .themeSpacing8) {
            if store.p2pAvailable {
                featureIcon(named: "ic-arrows-switch")
            }

            if store.torAvailable {
                featureIcon(named: "ic-brand-tor")
            }

            if store.isSmartAvailable {
                featureIcon(named: "ic-globe")
            }
        }
    }

    @ViewBuilder
    private func featureIcon(named name: String) -> some View {
        Image(name, bundle: CountriesResources.bundle)
            .resizable()
            .aspectRatio(contentMode: .fit)
            .frame(width: 16, height: 16)
            .foregroundColor(.white)
            .opacity(store.alphaOfMainElements)
    }

    @ViewBuilder
    private var chevronIcon: some View {
        Image("ic-chevron-right", bundle: CountriesResources.bundle)
            .resizable()
            .aspectRatio(contentMode: .fit)
            .frame(width: 24, height: 38)
            .foregroundColor(Color(.icon, .weak))
    }

    @ViewBuilder
    private var connectButton: some View {
        if let text = store.textInPlaceOfConnectIcon {
            // Upgrade button with text
            Text(text)
                .themeFont(.caption())
                .foregroundColor(Color(.text))
                .padding(.horizontal, .themeSpacing16)
                .padding(.vertical, .themeSpacing8)
                .background(store.connectButtonColor)
                .cornerRadius(.themeRadius8)
        } else {
            // Connect button with icon (interactive)
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
        CountryRow(
            store: Store(initialState: .previewNormal) {
                CountryFeature()
            },
            searchText: nil
        )
        .preferredColorScheme(.dark)
    }

    #Preview("Upgrade") {
        CountryRow(
            store: Store(initialState: .previewUpgrade) {
                CountryFeature()
            },
            searchText: nil
        )
        .preferredColorScheme(.dark)
    }

    #Preview("Secure Core") {
        CountryRow(
            store: Store(initialState: .previewSecureCore) {
                CountryFeature()
            },
            searchText: nil
        )
        .preferredColorScheme(.dark)
    }

    #Preview("With Flag") {
        CountryRow(
            store: Store(initialState: .previewWithFlag) {
                CountryFeature()
            },
            searchText: nil
        )
        .preferredColorScheme(.dark)
    }

    #Preview("No Connect Button") {
        CountryRow(
            store: Store(initialState: .previewNoConnectButton) {
                CountryFeature()
            },
            searchText: nil
        )
        .preferredColorScheme(.dark)
    }

    #Preview("Search Highlight") {
        CountryRow(
            store: Store(initialState: .previewNormal) {
                CountryFeature()
            },
            searchText: "Coun"
        )
        .preferredColorScheme(.dark)
    }
#endif
