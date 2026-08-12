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
import Strings
import SwiftUI
import Theme

/// Shows the countries a free user can connect to, with a banner that offers the rest of the network.
///
/// Home and Countries both present this in a sheet. On iOS the sheet asks for a height that fits the list, so a
/// handful of countries do not open a full-screen sheet. On macOS the presenting view sets the sheet size.
public struct FreeConnectionsView: View {
    let store: StoreOf<FreeConnectionsFeature>
    @Environment(\.dismiss) private var dismiss

    #if os(iOS)
        /// Height of the country list, measured while it lays out. The sheet detent follows it.
        @State private var contentHeight: CGFloat = .zero
        /// Room the home indicator takes from the bottom of the sheet. The detent has to pay for it as well.
        @State private var bottomInset: CGFloat = .zero
    #endif

    private let columns = [GridItem(.flexible()), GridItem(.flexible())]

    public init(store: StoreOf<FreeConnectionsFeature>) {
        self.store = store
    }

    public var body: some View {
        VStack(spacing: .themeSpacing0) {
            headerView

            ScrollView {
                countriesSection
            }
        }
        .background(Color(.background))
        .overlay(alignment: .topTrailing) {
            closeButton
                .padding([.top, .trailing], .themeSpacing16)
        }
        #if os(iOS)
        .background {
            // A reader that ignores the safe area reports how much of the sheet the home indicator covers.
            GeometryReader { geometry in
                Color.clear.preference(key: BottomInsetPreferenceKey.self, value: geometry.safeAreaInsets.bottom)
            }
            .ignoresSafeArea()
        }
        .onPreferenceChange(BottomInsetPreferenceKey.self) { newInset in
            bottomInset = newInset
        }
        .presentationDetents([.height(sheetHeight)])
        #endif
    }

    #if os(iOS)
        /// The height the sheet asks for: the header, the country list, and the bottom safe area.
        private var sheetHeight: CGFloat {
            Dimensions.headerSectionHeight + contentHeight + bottomInset
        }
    #endif

    private var countriesSection: some View {
        VStack(spacing: .themeSpacing24) {
            Text(Localizable.freeConnectionsModalDescription)
            #if os(macOS)
                .themeFont(.title2())
                .foregroundStyle(Color(.text, .weak))
                .multilineTextAlignment(.center)
            #else
                .themeFont(.body2())
                .foregroundStyle(Color(.text))
            #endif

            Text(Localizable.freeConnectionsModalSubtitle(store.countries.count))
            #if os(macOS)
                .themeFont(.body(emphasised: true))
                .multilineTextAlignment(.center)
            #else
                .themeFont(.body1(.bold))
                .multilineTextAlignment(.leading)
                .frame(maxWidth: .infinity, alignment: .leading)
            #endif
                .foregroundStyle(Color(.text))

            LazyVGrid(columns: columns, alignment: .leading, spacing: .themeSpacing8) {
                ForEach(store.countries) { country in
                    countryCell(country)
                }
            }

            upgradeBanner
        }
        #if os(macOS)
        .padding(.horizontal, .themeSpacing48)
        #else
        .padding(.horizontal, .themeSpacing12)
        .padding(.bottom, .themeSpacing16)
        .overlay {
            GeometryReader { geometry in
                Color.clear.preference(key: ContentHeightPreferenceKey.self, value: geometry.size.height)
            }
        }
        .onPreferenceChange(ContentHeightPreferenceKey.self) { newHeight in
            contentHeight = newHeight
        }
        #endif
    }

    private var headerView: some View {
        ZStack {
            Text(Localizable.freeConnectionsModalTitle)
            #if os(macOS)
                .themeFont(.title1(emphasised: true))
            #else
                .themeFont(.body1(.bold))
            #endif
                .foregroundStyle(Color(.text))
        }
        .frame(height: Dimensions.headerHeight)
        .padding(.horizontal, .themeSpacing16)
        .padding(.top, Dimensions.headerTopPadding)
    }

    private var closeButton: some View {
        Button {
            dismiss()
        } label: {
            Theme.Asset.Icons.crossBig.swiftUIImage
                .resizable()
                .foregroundStyle(Color(.icon))
                .frame(.square(Dimensions.closeButtonSize))
        }
        .buttonStyle(.plain)
    }

    private func countryCell(_ country: FreeConnectionsFeature.State.Country) -> some View {
        HStack(spacing: .themeSpacing8) {
            if let flag = Theme.ImageAsset.Image.flag(countryCode: country.code) {
                flag.swiftUIImage
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .frame(width: Dimensions.flagWidth, height: Dimensions.flagHeight)
                    .cornerRadius(.themeRadius2)
            }
            Text(country.name)
            #if os(macOS)
                .themeFont(.title3())
            #else
                .themeFont(.body2())
            #endif
                .foregroundStyle(Color(.text))
            Spacer(minLength: 0)
        }
        .padding(.vertical, .themeSpacing4)
    }

    private var upgradeBanner: some View {
        Button {
            store.send(.upgradeTapped)
        } label: {
            HStack(spacing: .themeSpacing12) {
                Asset.worldwideCoverage.swiftUIImage
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(.square(Dimensions.bannerIconSize))

                Text(Localizable.freeConnectionsModalBanner)
                #if os(macOS)
                    .themeFont(.headline())
                #else
                    .themeFont(.body3())
                #endif
                    .foregroundStyle(Color(.text))
                    .multilineTextAlignment(.leading)

                Spacer(minLength: 0)

                Image(systemName: "chevron.right")
                    .foregroundStyle(Color(.text, .weak))
            }
            .padding(.themeSpacing12)
            .frame(maxWidth: .infinity, idealHeight: Dimensions.bannerIdealHeight, alignment: .leading)
            .background(Color(.background, .weak))
            .clipShape(RoundedRectangle(cornerRadius: .themeRadius12))
        }
        .buttonStyle(.plain)
        .frame(maxWidth: .infinity)
    }

    private enum Dimensions {
        static let closeButtonSize: CGFloat = 12
        static let headerHeight: CGFloat = 44
        static let headerTopPadding: CGFloat = 24
        /// The title and the padding above it, the part of the sheet that sits outside the measured country list.
        static let headerSectionHeight: CGFloat = headerHeight + headerTopPadding
        static let flagWidth: CGFloat = 24
        static let flagHeight: CGFloat = 16
        static let bannerIconSize: CGFloat = 40
        static let bannerIdealHeight: CGFloat = 74
    }
}

#if os(iOS)
    private struct ContentHeightPreferenceKey: PreferenceKey {
        static let defaultValue: CGFloat = .zero

        static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
            value = nextValue()
        }
    }

    private struct BottomInsetPreferenceKey: PreferenceKey {
        static let defaultValue: CGFloat = .zero

        static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
            value = nextValue()
        }
    }
#endif

#if DEBUG
    #Preview("Free Connections") {
        FreeConnectionsView(
            store: Store(initialState: .mock) {
                FreeConnectionsFeature()
            }
        )
        .preferredColorScheme(.dark)
    }
#endif
