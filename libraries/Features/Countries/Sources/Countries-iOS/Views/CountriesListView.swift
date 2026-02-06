//
//  Created on 16/01/2026 by Max Kupetskyi.
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
import CountriesShared
import ProtonCoreUIFoundations
import SwiftUI
import Theme

struct CountriesListView: View {
    @Bindable var store: StoreOf<CountriesFeature>

    var body: some View {
        List {
            ForEach(store.scope(state: \.sections, action: \.sections)) { (sectionStore: StoreOf<CountrySectionFeature>) in
                Section {
                    ForEach(sectionStore.scope(state: \.rows, action: \.rows)) { (rowStore: StoreOf<RowFeature>) in
                        Group {
                            switch rowStore.state {
                            case .country:
                                if let countryStore = rowStore.scope(state: \.country, action: \.country) {
                                    Text("CountryRow")
                                }
                            case .profile:
                                if let profileStore = rowStore.scope(state: \.profile, action: \.profile) {
                                    Text("ProfileRow")
                                }
                            case .banner:
                                if let bannerStore = rowStore.scope(state: \.banner, action: \.banner) {
                                    Text("BannerRow")
                                }
                            case .offerBanner:
                                if let offerBannerStore = rowStore.scope(state: \.offerBanner, action: \.offerBanner) {
                                    Text("OfferBanner")
                                }
                            }
                        }
                        .listRowSeparator(.hidden)
                        .listRowBackground(Color(.background))
                        .listRowInsets(.zero)
                    }
                } header: {
                    if store.sections.count >= 2,
                       let title = sectionStore.title {
                        ServersHeaderSwiftUIView(
                            title: title,
                            callback: { sectionStore.send(.infoButtonTapped) }
                        )
                    }
                }
            }
        }
        .listStyle(.plain)
        .scrollContentBackground(.hidden)
        .background(Color(.background))
    }
}

// MARK: - SwiftUI ServersHeader

struct ServersHeaderSwiftUIView: View {
    let title: String
    let callback: (() -> Void)?

    var body: some View {
        HStack {
            Text(title)
                .themeFont(.body2(emphasised: false))
                .foregroundColor(Color(.text, .weak))

            Spacer()

            if let callback {
                Button(action: callback) {
                    Image(uiImage: IconProvider.infoCircle)
                        .foregroundColor(Color(uiColor: .iconNorm()))
                        .frame(width: 24, height: 24)
                }
                .buttonStyle(PlainButtonStyle())
            }
        }
        .padding(.horizontal, .themeSpacing16)
        .padding(.vertical, .themeSpacing8)
        .listRowInsets(EdgeInsets())
        .background(Color(.background))
    }
}

extension EdgeInsets {
    static let zero = EdgeInsets(top: 0, leading: 0, bottom: 0, trailing: 0)
}
