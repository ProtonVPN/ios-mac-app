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

public struct UpsellBannerView: View {
    let numberOfCountries: Int
    let onUpgrade: () -> Void

    public init(numberOfCountries: Int, onUpgrade: @escaping () -> Void) {
        self.numberOfCountries = numberOfCountries
        self.onUpgrade = onUpgrade
    }

    public var body: some View {
        Button(action: onUpgrade) {
            HStack(spacing: .themeSpacing8) {
                Image("ic-earth", bundle: CountriesResources.bundle)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(.square(24))
                    .foregroundColor(Color(.icon, .weak))

                VStack(alignment: .leading, spacing: .themeSpacing8) {
                    Text(Localizable.searchUpsellTitle(numberOfCountries))
                        .foregroundColor(Color(.text))
                        .themeFont(.body2(emphasised: true))

                    Text(Localizable.searchUpsellSubtitle)
                        .themeFont(.caption())
                        .foregroundColor(Color(.text, .weak))
                        .multilineTextAlignment(.leading)
                }

                Spacer()

                Image("ic-chevron-right", bundle: CountriesResources.bundle)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(.square(16))
                    .foregroundColor(Color(.icon, .hint))
            }
            .padding(.themeSpacing16)
            .background(Color(.background, .weak))
            .cornerRadius(.themeRadius12)
        }
        .buttonStyle(.plain)
    }
}

#if DEBUG
    #Preview("Upsell Banner") {
        UpsellBannerView(numberOfCountries: 42, onUpgrade: {})
            .padding()
            .preferredColorScheme(.dark)
    }
#endif
