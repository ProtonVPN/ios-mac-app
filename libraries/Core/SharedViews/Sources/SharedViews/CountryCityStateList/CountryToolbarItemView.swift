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
import Sharing
import SwiftUI
import Theme
import VPNAppCore

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
            self.flag = .stacked(
                bottom: .country(code: entryCountryCode),
                top: .country(code: server.logical.exitCountryCode)
            )
            let location: ConnectionSpec.Location = .secureCore(.hop(to: server.logical.exitCountryCode, via: entryCountryCode))
            self.title = location.text(locale: .current)
            if let subtext = location.subtext(locale: .current) {
                self.subheader = .textual(.withoutFeatures(location: subtext))
            }
        case .gateway:
            self.flag = .standard(.country(code: server.logical.exitCountryCode))
            self.title = server.logical.name
        }
    }

    public init(kind: ServerGroupInfo.Kind) {
        @SharedReader(.secureCoreToggle) var secureCoreToggle: Bool

        let location: ConnectionSpec.Location

        switch kind {
        case let .city(name, code):
            self.flag = .standard(.country(code: code))
            location = .city(name: name, code: code, order: .fastest)
        case let .state(name, code):
            self.flag = .standard(.country(code: code))
            location = .state(name: name, code: code, order: .fastest)
        case let .country(code):
            if secureCoreToggle {
                self.flag = .withCurve(.country(code: code))
            } else {
                self.flag = .standard(.country(code: code))
            }
            location = .country(code: code, order: .fastest)
        case let .gateway(name):
            self.flag = .standard(.gateway)
            location = .gateway(name: name)
        }
        self.title = location.headerText(locale: .current) ?? ""
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

#Preview {
    CountryToolbarItemView(kind: .country(code: "PL"))
        .padding()
        .background(.cyan)
}
