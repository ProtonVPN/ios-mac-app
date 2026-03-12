//
//  Created on 12/03/2026 by Max Kupetskyi.
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
import Strings
import SwiftUI
import Theme
import UIKit

struct FreeConnectionsView: View {
    let store: StoreOf<FreeConnectionsFeature>
    @Environment(\.dismiss) private var dismiss

    private let columns = [GridItem(.flexible()), GridItem(.flexible())]

    var body: some View {
        VStack(spacing: .themeSpacing0) {
            headerView

            ScrollView {
                VStack(alignment: .leading, spacing: .themeSpacing24) {
                    Text(Localizable.freeConnectionsModalDescription)
                        .themeFont(.body2())
                        .foregroundStyle(Color(.text))

                    Text(Localizable.freeConnectionsModalSubtitle(store.countries.count))
                        .themeFont(.body1(.bold))
                        .foregroundStyle(Color(.text))

                    LazyVGrid(columns: columns, alignment: .leading, spacing: .themeSpacing8) {
                        ForEach(store.countries) { country in
                            countryCell(country)
                        }
                    }

                    upgradeBanner
                }
                .padding(.themeSpacing16)
            }
        }
        .background(Color(.background))
    }

    private var headerView: some View {
        ZStack {
            Text(Localizable.freeConnectionsModalTitle)
                .themeFont(.body1(.bold))
                .foregroundStyle(Color(.text))

            HStack {
                Button(action: { dismiss() }) {
                    Theme.Asset.Icons.crossBig.swiftUIImage
                        .foregroundStyle(Color(.text))
                        .frame(.square(24))
                        .padding(.themeSpacing4)
                }
                .padding(.leading, .themeSpacing12)

                Spacer()
            }
        }
        .frame(height: 44)
        .padding(.top, .themeSpacing8)
    }

    @ViewBuilder
    private func countryCell(_ country: FreeConnectionsFeature.State.Country) -> some View {
        HStack(spacing: .themeSpacing8) {
            if let flag = ImageAsset.Image.flag(countryCode: country.code) {
                flag.swiftUIImage
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .frame(width: 24, height: 16)
                    .cornerRadius(.themeRadius2)
            }
            Text(country.name)
                .themeFont(.body2())
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
                    .frame(.square(30))

                Text(Localizable.freeConnectionsModalBanner)
                    .themeFont(.body3())
                    .foregroundStyle(Color(.text))
                    .multilineTextAlignment(.leading)

                Spacer(minLength: 0)

                Image(systemName: "chevron.right")
                    .foregroundStyle(Color(.text, .weak))
            }
            .padding(.themeSpacing12)
            .frame(maxWidth: .infinity, idealHeight: 74, alignment: .leading)
            .background(Color(.background, .weak))
            .clipShape(RoundedRectangle(cornerRadius: .themeRadius12))
        }
        .buttonStyle(.plain)
        .frame(maxWidth: .infinity)
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
