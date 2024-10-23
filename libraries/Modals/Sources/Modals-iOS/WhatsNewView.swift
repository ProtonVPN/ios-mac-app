//
//  Created on 21/08/2023.
//
//  Copyright (c) 2023 Proton AG
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

import Modals
import SharedViews
import Strings

@MainActor
public struct WhatsNewView: View {
    public enum PlanVariant {
        case free
        case plus
        case business
    }

    @Environment(\.dismiss) private var dismiss

    let variant: PlanVariant

    public var body: some View {
        VStack(spacing: .themeSpacing24) {
            imageAssetView
                .resizable()
                .scaledToFit()
                .padding(.bottom, .themeSpacing16)

            Text(Localizable.modalsWhatsNew)
                .themeFont(.headline)

            textContentView

            Spacer()

            Button {
                dismiss()
            } label: {
                Text(Localizable.modalsWhatsNewButtonTitle)
            }
            .buttonStyle(PrimaryButtonStyle())
            .padding(.top, .themeSpacing12)
        }
        .padding(.horizontal, .themeSpacing16)
        .padding(.top, .themeSpacing16)
        .padding(.bottom, .themeSpacing12)
    }

    private var imageAssetView: SwiftUI.Image {
        switch variant {
        case .free, .plus:
            return Asset.whatsNewFreePlus.swiftUIImage
        case .business:
            return Asset.whatsNewBusiness.swiftUIImage
        }
    }

    private var freePlanTextContentView: some View {
        VStack(alignment: .leading, spacing: .themeSpacing2) {
            Text(Localizable.modalsWhatsNewRedesignTitle)
                .themeFont(.body1(.bold))

            Text(Localizable.modalsWhatsNewRedesignSubtitle)
                .themeFont(.body2(emphasised: false))
                .foregroundColor(Color(.text, .weak))
        }
    }

    private var recentsTextContentView: some View {
        VStack(alignment: .leading, spacing: .themeSpacing2) {
            Text(Localizable.modalsWhatsNewRecentsTitle)
                .themeFont(.body1(.bold))

            Text(Localizable.modalsWhatsNewRecentsSubtitle)
                .themeFont(.body2(emphasised: false))
                .foregroundColor(Color(.text, .weak))
        }
    }

    private var gatewaysTextContentView: some View {
        VStack(alignment: .leading, spacing: .themeSpacing2) {
            Text(Localizable.modalsWhatsNewGatewaysTitle)
                .themeFont(.body1(.bold))

            Text(Localizable.modalsWhatsNewGatewaysSubtitle)
                .themeFont(.body2(emphasised: false))
                .foregroundColor(Color(.text, .weak))
        }
    }

    @ViewBuilder
    private var textContentView: some View {
        switch variant {
        case .free:
            freePlanTextContentView
        case .plus:
            freePlanTextContentView
            recentsTextContentView
        case .business:
            recentsTextContentView
            gatewaysTextContentView
        }
    }
}

struct WhatsNewView_Previews: PreviewProvider {
    static var previews: some View {
        WhatsNewView(variant: .plus)
    }
}
