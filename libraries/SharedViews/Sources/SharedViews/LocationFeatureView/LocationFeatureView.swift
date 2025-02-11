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

/// Manages the complexity of aligning the flag + header + subheader combo.
public struct LocationFeatureModel: Equatable {
    let flag: FlagComposition
    let header: LocationFeatureHeaderModel
    let subheader: LocationFeatureSubheaderModel

    public init(flag: FlagComposition, header: LocationFeatureHeaderModel, subheader: LocationFeatureSubheaderModel) {
        self.flag = flag
        self.header = header
        self.subheader = subheader
    }

    public init(flag: Flag, header: LocationFeatureHeaderModel, subheader: LocationFeatureSubheaderModel) {
        self.init(flag: .standard(flag), header: header, subheader: subheader)
    }
}

public struct LocationFeatureView: View {
    let model: LocationFeatureModel
    let attachedLeadingView: AnyView?

    public init(model: LocationFeatureModel, attachedLeadingView: (() -> AnyView)? = nil) {
        self.attachedLeadingView = attachedLeadingView?()
        self.model = model
    }

    public var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: 12) {
            HStack(alignment: .center, spacing: 0) {
                attachedLeadingView
                FlagView(flag: model.flag, flagSize: .defaultSize)
            }
            .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: 0) {
                LocationFeatureHeader(model: model.header)
                LocationFeatureSubheader(model: model.subheader) // can resolve to EmptyView()
            }
        }
    }
}

#if DEBUG
#Preview {
    VStack(alignment: .leading) {
        LocationFeatureView(model: .init(
            flag: .country(code: "US"),
            header: .init(title: "Czechia", showConnectedPin: false),
            subheader: .textual(
                .init(location: "Prague #34", showTor: true, showP2P: true)
            )
        ))

        LocationFeatureView(model: .init(
            flag: .fastest,
            header: .init(title: "Fastest", showConnectedPin: false),
            subheader: .none
        ))

        LocationFeatureView(model: .init(
            flag: .stacked(bottom: .country(code: "PL"), top: .country(code: "JP")),
            header: .init(title: "Poland", showConnectedPin: false),
            subheader: .textual(.init(location: "via Japan", showTor: false, showP2P: true))
        ))
    }
    .padding()
    .preferredColorScheme(.dark)
}
#endif
