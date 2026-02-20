//
//  Created on 28/01/2026 by Max Kupetskyi.
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

import CountriesShared
import Strings
import SwiftUI
import Theme

struct PlaceholderContentView: View {
    let onlyCountries: Bool

    private var items: [PlaceholderItem] {
        onlyCountries ? [.countries] : [.countries, .cities, .servers]
    }

    public var body: some View {
        VStack(alignment: .center, spacing: .themeSpacing16) {
            Image("SearchGlass", bundle: CountriesResources.bundle)
                .frame(.square(100))

            Text(Localizable.searchSubtitle)
                .themeFont(.headline)
                .foregroundColor(Color(.text))
                .padding(.horizontal, .themeSpacing16)

            ForEach(items, id: \.self) { item in
                HStack(spacing: .themeSpacing4) {
                    Image("ic-magnifier", bundle: CountriesResources.bundle)
                        .frame(.square(16))
                        .foregroundStyle(Color(.background, .interactive))
                    Text(item.title)
                        .themeFont(.body2(emphasised: true))
                        .foregroundStyle(Color(.text))
                    Text(item.subtitle)
                        .themeFont(.body2())
                        .foregroundStyle(Color(.text, .weak))
                    Spacer()
                }
                .padding(.horizontal, .themeSpacing32)
            }

            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .background(Color(.background))
        .padding(.top, .themeSpacing36)
    }
}

enum PlaceholderItem: CaseIterable {
    case countries
    case cities
    case usRegions
    case servers
}

extension PlaceholderItem {
    var title: String {
        switch self {
        case .countries:
            Localizable.searchCountries
        case .cities:
            Localizable.searchCities
        case .usRegions:
            Localizable.searchUsRegions
        case .servers:
            Localizable.searchServers
        }
    }

    var subtitle: String {
        switch self {
        case .countries:
            Localizable.searchCountriesSample
        case .cities:
            Localizable.searchCitiesSample
        case .usRegions:
            Localizable.searchUsRegionsSample
        case .servers:
            Localizable.searchServersSample
        }
    }
}
