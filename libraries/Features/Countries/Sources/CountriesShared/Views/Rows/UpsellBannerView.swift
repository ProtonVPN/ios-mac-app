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

import Strings
import SwiftUI
import Theme

public struct UpsellBannerView: View {
    public enum Variant: Equatable {
        case search(numberOfCountries: Int)
        case allCountries
        case wrongCountry

        var iconName: String {
            switch self {
            case .search:
                "ic-earth"
            case .allCountries:
                "worldwide-coverage"
            case .wrongCountry:
                "wrong-country"
            }
        }

        var title: String {
            switch self {
            case let .search(numberOfCountries):
                Localizable.searchUpsellTitle(numberOfCountries)
            case .allCountries:
                Localizable.freeBannerText
            case .wrongCountry:
                Localizable.wrongCountryBannerText
            }
        }

        var subtitle: String? {
            switch self {
            case .search:
                Localizable.searchUpsellSubtitle
            case .allCountries, .wrongCountry:
                nil
            }
        }
    }

    private let variant: Variant
    private let onUpgrade: () -> Void

    public init(variant: Variant, onUpgrade: @escaping () -> Void) {
        self.variant = variant
        self.onUpgrade = onUpgrade
    }

    public var body: some View {
        Button(action: onUpgrade) {
            HStack(spacing: .themeSpacing8) {
                Image(variant.iconName, bundle: CountriesResources.bundle)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                #if os(iOS)
                    .frame(.square(24))
                #else
                    .frame(.square(48))
                #endif
                    .foregroundColor(Color(.icon, .weak))

                VStack(alignment: .leading, spacing: .themeSpacing8) {
                    Text(variant.title)
                        .foregroundColor(Color(.text))
                    #if os(iOS)
                        .themeFont(.body2(emphasised: true))
                    #else
                        .font(.body(emphasised: false))
                    #endif

                    if let subtitle = variant.subtitle {
                        Text(subtitle)
                        #if os(iOS)
                            .themeFont(.caption())
                        #endif
                            .foregroundColor(Color(.text, .weak))
                            .multilineTextAlignment(.leading)
                    }
                }

                Spacer()

                Image("ic-chevron-right", bundle: CountriesResources.bundle)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(.square(16))
                    .foregroundColor(Color(.icon, .hint))
            }
            .padding(.themeSpacing16)
            .background(in: RoundedRectangle(cornerRadius: .themeRadius12))
        }
        .buttonStyle(.plain)
        #if os(iOS)
            .backgroundStyle(Color(.background, .weak))
        #else
            .backgroundStyle(Color(.background, .transparent))
        #endif
    }
}

#if DEBUG
    #Preview("Upsell Banner Search") {
        UpsellBannerView(variant: .search(numberOfCountries: 42), onUpgrade: {})
            .padding()
            .preferredColorScheme(.dark)
    }
#endif
