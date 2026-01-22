//
//  Created on 2026-01-13 by Pawel Jurczyk.
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

import Domain
import SharedViews
import SwiftUI

struct ServerToolbarItemView: View {
    let countryCode: String
    let city: String

    let location: ConnectionSpec.Location

    init(city: String, countryCode: String) {
        self.city = city
        self.countryCode = countryCode
        self.location = .city(name: city, code: countryCode, order: .fastest)
    }

    var body: some View {
        LocationFeatureView(
            model: .init(
                flag: .country(code: countryCode),
                header: .init(
                    title: location.headerText(locale: .current) ?? countryCode,
                    showConnectedPin: false
                ),
                subheader: .textual(.withoutFeatures(location: city))
            ),
            attachedLeadingView: nil
        )
        .padding(.top, .themeSpacing16)
    }
}
