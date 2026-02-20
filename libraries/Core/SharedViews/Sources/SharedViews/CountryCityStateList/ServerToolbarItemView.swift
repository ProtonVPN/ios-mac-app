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
import SwiftUI
import Theme

public struct ServerToolbarItemView: View {
    let flag: Flag
    let subheader: LocationFeatureSubheaderModel
    let location: ConnectionSpec.Location

    public init(kind: ServerGroupInfo.Kind) {
        switch kind {
        case .city(let name, let code):
            flag = .country(code: code)
            location = .city(name: name, code: code, order: .fastest)
            subheader = .textual(.withoutFeatures(location: name))
        case .state(let name, let code):
            flag = .country(code: code)
            location = .state(name: name, code: code, order: .fastest)
            subheader = .textual(.withoutFeatures(location: name))
        case .country(let code):
            flag = .country(code: code)
            location = .country(code: code, order: .fastest)
            subheader = .none
        case .gateway(let name):
            flag = .gateway
            location = .gateway(name: name)
            subheader = .none
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
                subheader: subheader
            ),
            attachedLeadingView: nil
        )
    }
}
