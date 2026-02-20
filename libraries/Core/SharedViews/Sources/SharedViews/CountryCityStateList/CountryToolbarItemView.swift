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
import SwiftUI
import Theme

public struct CountryToolbarItemView: View {

    let location: ConnectionSpec.Location

    let flag: Flag

    public init(groupInfo: ServerGroupInfo) {
        switch groupInfo.kind {
        case .city(let name, let code):
            flag = .country(code: code)
            location = .city(name: name, code: code, order: .fastest)
        case .state(let name, let code):
            flag = .country(code: code)
            location = .state(name: name, code: code, order: .fastest)
        case .country(let code):
            flag = .country(code: code)
            location = .country(code: code, order: .fastest)
        case .gateway(let name):
            flag = .gateway
            location = .gateway(name: name)
        }
    }

    public var body: some View {
        LocationFeatureView(
            model: .init(
                flag: flag,
                header: .init(
                    title: location.headerText(locale: .current) ?? "",
                    showConnectedPin: false
                ),
                subheader: .none
            ),
            attachedLeadingView: nil
        )
    }
}

//#Preview {
//    CountryToolbarItemView(countryCode: "PL")
//        .padding()
//        .background(.cyan)
//}
