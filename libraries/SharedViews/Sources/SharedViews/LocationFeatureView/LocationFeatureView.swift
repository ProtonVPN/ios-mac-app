//
//  Created on 05/12/2024.
//
//  Copyright (c) 2024 Proton AG
//
//  ProtonVPN is free software: you can redistribute it and/or modify
//  it under the terms of the GNU General Public License as published by
//  the Free Software Foundation, either version 3 of the License, or
//  (at your option) any later version.
//
//  ProtonVPN is distributed in the hope that it will be useful,
//  but WITHOUT ANY WARRANTY; without even the implied warranty of
//  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
//  GNU General Public License for more details.
//
//  You should have received a copy of the GNU General Public License
//  along with ProtonVPN.  If not, see <https://www.gnu.org/licenses/>.

import Foundation
import Domain
import Theme

import SwiftUI

struct LocationFeatureModel {
    let location: ConnectionSpec.Location
    let header: LocationFeatureHeaderModel
    let subheader: LocationFeatureSubheaderModel
}

struct LocationFeatureView: View {
    let model: LocationFeatureModel

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: 12) {
            FlagView(location: model.location, flagSize: .defaultSize)

            VStack(alignment: .leading, spacing: 0) {
                LocationFeatureHeader(model: model.header)
                LocationFeatureSubheader(model: model.subheader) // can be an EmptyView()
            }
        }
    }
}

#if DEBUG
#Preview {
    VStack(alignment: .leading) {
        LocationFeatureView(model: .init(
            location: .region(code: "US"),
            header: .init(title: "Czechia", showConnectedPin: false),
            subheader: .textual(
                .init(location: "Prague #34", showTor: true, showP2P: true)
            )
        ))

        LocationFeatureView(model: .init(
            location: .region(code: "Fastest"),
            header: .init(title: "Fastest", showConnectedPin: false),
            subheader: .none
        ))

        LocationFeatureView(model: .init(
            location: .secureCore(.hop(to: "PL", via: "JP")),
            header: .init(title: "Poland", showConnectedPin: false),
            subheader: .textual(.init(location: "via Japan", showTor: false, showP2P: true))
        ))
    }
    .padding()
    .preferredColorScheme(.dark)
}
#endif
