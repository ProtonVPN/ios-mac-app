//
//  Created on 2025-12-24 by Pawel Jurczyk.
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

import Domain
import SharedViews
import SwiftUI

struct CountryToolbarItemView: View {
    let countryCode: String

    let location: ConnectionSpec.Location

    init(countryCode: String) {
        self.countryCode = countryCode
        self.location = .country(code: countryCode, order: .fastest)
    }

    var body: some View {
        LocationFeatureView(
            model: .init(
                flag: .country(code: countryCode),
                header: .init(
                    title: location.headerText(locale: .current) ?? countryCode,
                    showConnectedPin: false
                ),
                subheader: .none
            ),
            attachedLeadingView: nil
        )
        .padding(.top, .themeSpacing16)
    }
}
