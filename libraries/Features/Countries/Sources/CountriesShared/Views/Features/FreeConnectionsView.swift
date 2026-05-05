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

public struct FreeConnectionsView: View {
    let store: StoreOf<FreeConnectionsFeature>
    @Environment(\.dismiss) private var dismiss

    private let columns = [GridItem(.flexible()), GridItem(.flexible())]

    public init(store: StoreOf<FreeConnectionsFeature>) {
        self.store = store
    }

    public var body: some View {
        VStack(spacing: .themeSpacing0) {
            headerView
                .padding(.top, .themeSpacing16)

            ScrollView {
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
                #endif
            }
        }
        .background(Color(.background))
        .overlay(alignment: .topTrailing) {
            closeButton
                .padding([.top, .trailing], .themeSpacing16)
        }
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
        .padding(.top, .themeSpacing8)
    }

    private var closeButton: some View {
        Button(action: { dismiss() }) {
            Theme.Asset.Icons.crossBig.swiftUIImage
                .resizable()
                .foregroundStyle(Color(.icon))
                .frame(.square(Dimensions.closeButtonSize))
        }
        .buttonStyle(.plain)
    }

    private func countryCell(_ country: FreeConnectionsFeature.State.Country) -> some View {
        HStack(spacing: .themeSpacing8) {
            if let flag = ImageAsset.Image.flag(countryCode: country.code) {
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
        Button(action: { store.send(.upgradeTapped) }) {
            HStack(spacing: .themeSpacing12) {
                Image("worldwide-coverage", bundle: CountriesResources.bundle)
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
        static let flagWidth: CGFloat = 24
        static let flagHeight: CGFloat = 16
        static let bannerIconSize: CGFloat = 40
        static let bannerIdealHeight: CGFloat = 74
    }
}

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
