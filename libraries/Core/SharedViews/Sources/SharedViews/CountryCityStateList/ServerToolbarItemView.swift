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
        case let .city(name, code):
            self.flag = .country(code: code)
            self.location = .city(name: name, code: code, order: .fastest)
            self.subheader = .textual(.withoutFeatures(location: name))
        case let .state(name, code):
            self.flag = .country(code: code)
            self.location = .state(name: name, code: code, order: .fastest)
            self.subheader = .textual(.withoutFeatures(location: name))
        case let .country(code):
            self.flag = .country(code: code)
            self.location = .country(code: code, order: .fastest)
            self.subheader = .none
        case let .gateway(name):
            self.flag = .gateway
            self.location = .gateway(name: name)
            self.subheader = .none
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
