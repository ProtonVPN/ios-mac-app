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
    let numberOfCountries: Int
    let onUpgrade: () -> Void

    public init(numberOfCountries: Int, onUpgrade: @escaping () -> Void) {
        self.numberOfCountries = numberOfCountries
        self.onUpgrade = onUpgrade
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: .themeSpacing12) {
            Text(Localizable.searchUpsellTitle(numberOfCountries))
                .foregroundColor(.white)
                .themeFont(.body2(emphasised: true))

            Button(action: onUpgrade) {
                Text(Localizable.searchUpsellSubtitle)
                    .themeFont(.body2(emphasised: true))
                    .foregroundColor(.white)
                    .padding(.horizontal, .themeSpacing16)
                    .padding(.vertical, .themeSpacing8)
                    .background(Color(uiColor: .brandColor()))
                    .cornerRadius(.themeRadius8)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.themeSpacing16)
        .background(Color(uiColor: .weakInteractionColor()))
        .cornerRadius(.themeRadius8)
    }
}
