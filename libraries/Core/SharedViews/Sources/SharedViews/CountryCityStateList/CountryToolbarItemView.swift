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
import VPNAppCore
import Sharing

public struct CountryToolbarItemView: View {

    let title: String

    let flag: FlagComposition

    var subheader: LocationFeatureSubheaderModel = .none

    // We present the server with a flag if it's a secure core server or a gateway server
    public init?(server: ServerInfo) {
        switch server.logical.kind {
        case .country:
            return nil
        case let .secureCore(entryCountryCode):
            flag = .stacked(bottom: .country(code: entryCountryCode),
                            top: .country(code: server.logical.exitCountryCode))
            let location: ConnectionSpec.Location = .secureCore(.hop(to: server.logical.exitCountryCode, via: entryCountryCode))
            title = location.text(locale: .current)
            if let subtext = location.subtext(locale: .current) {
                subheader = .textual(.withoutFeatures(location: subtext))
            }
        case .gateway:
            flag = .standard(.country(code: server.logical.exitCountryCode))
            title = server.logical.name
        }
    }

    public init(kind: ServerGroupInfo.Kind) {
        @SharedReader(.secureCoreToggle) var secureCoreToggle: Bool

        let location: ConnectionSpec.Location

        switch kind {
        case .city(let name, let code):
            flag = .standard(.country(code: code))
            location = .city(name: name, code: code, order: .fastest)
        case .state(let name, let code):
            flag = .standard(.country(code: code))
            location = .state(name: name, code: code, order: .fastest)
        case .country(let code):
            if secureCoreToggle {
                flag = .withCurve(.country(code: code))
            } else {
                flag = .standard(.country(code: code))
            }
            location = .country(code: code, order: .fastest)
        case .gateway(let name):
            flag = .standard(.gateway)
            location = .gateway(name: name)
        }
        title = location.headerText(locale: .current) ?? ""
        location.subtext(locale: .current)
    }

    public var body: some View {
        LocationFeatureView(
            model: .init(
                flag: flag,
                header: .init(
                    title: title,
                    showConnectedPin: false
                ),
                subheader: subheader
            ),
            attachedLeadingView: nil
        )
        .lineLimit(1)
    }
}

//#Preview {
//    CountryToolbarItemView(countryCode: "PL")
//        .padding()
//        .background(.cyan)
//}
