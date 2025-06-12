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

import SwiftUI
import Strings
import enum Theme.Asset
import var ProtonCoreUIFoundations.IconProvider

public struct LocationFeatureSubheader: View {
    private let model: LocationFeatureSubheaderModel

    public init(model: LocationFeatureSubheaderModel) {
        self.model = model
    }

    public var body: some View {
        content
            .frame(maxWidth: .infinity, alignment: .leading)
            .fixedSize(horizontal: false, vertical: true)
            .foregroundColor(Color(.text, .weak))
        #if canImport(Cocoa)
            .font(.body())
        #elseif canImport(UIKit)
            .font(.body2(emphasised: false))
        #endif
    }

    @ViewBuilder private var content: some View {
        switch model {
        case let .textual(textModel):
            [Text(textModel.location)]
                .appending(torText, if: textModel.showTor)
                .appending(p2pText, if: textModel.showP2P)
                .joined(separator: Text(" • "))

        case .freeServerSelectionDisclaimer:
            freeServerSelectionDisclaimerView

        case .none:
            EmptyView()
        }
    }

    private var freeServerSelectionDisclaimerView: some View {
        HStack(spacing: .themeSpacing4) {
            Text(Localizable.homeFastestConnectionSelectionDescription)
            Asset.freeFlags.swiftUIImage
            Text(Localizable.homeFastestConnectionAdditionalCountryCount(2))
        }
    }

    private var torText: Text {
        Text(Asset.icsBrandTor.swiftUIImage)
            + Text(" \(Localizable.connectionDetailsFeatureTitleTor)")
    }

    private var p2pText: Text {
        Text(Image(systemName: "arrow.left.arrow.right"))
            + Text(" \(Localizable.connectionDetailsFeatureTitleP2p)")
    }
}

public enum LocationFeatureSubheaderModel: Equatable {
    case textual(TextSubheaderModel)
    case freeServerSelectionDisclaimer(additionalFreeCountryCount: Int)
    case none

    public struct TextSubheaderModel: Equatable {
        let location: String
        let showTor: Bool
        let showP2P: Bool

        public init(location: String, showTor: Bool, showP2P: Bool) {
            self.location = location
            self.showTor = showTor
            self.showP2P = showP2P
        }

        public static func withoutFeatures(location: String) -> Self {
            self.init(location: location, showTor: false, showP2P: false)
        }
    }
}
