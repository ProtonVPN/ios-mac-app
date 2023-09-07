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
import SharedViews
import Strings
import Theme

struct WhatsNewView: View {

    @Environment(\.dismiss) var dismiss

    var body: some View {
        VStack(spacing: .themeSpacing24) {
            Spacer()
            Asset.welcomeToProtonVpn.swiftUIImage

            Text(Localizable.modalsWhatsNew)
                .themeFont(.headline)
            VStack(alignment: .leading, spacing: .themeSpacing4) {
                HStack {
                    Text(Localizable.modalsFreeCountries)
                        .themeFont(.body1(.bold))
                    Spacer(minLength: 0)
                }
                HStack {
                    Text(Localizable.modalsNewServers)
                        .themeFont(.body2())
                        .foregroundColor(Color(.text, .weak))
                    Spacer(minLength: 0)
                }
            }
            VStack(alignment: .leading, spacing: .themeSpacing4) {
                HStack {
                    Text(Localizable.modalsServerSelection)
                        .themeFont(.body1(.bold))
                    Spacer(minLength: 0)
                }
                HStack {
                    Text(Localizable.modalsServerCrowding)
                        .themeFont(.body2())
                        .foregroundColor(Color(.text, .weak))
                    Spacer(minLength: 0)
                }
            }
            Spacer()
            Button {
                dismiss()
            } label: {
                Text(Localizable.gotIt)
            }
            .buttonStyle(PrimaryButtonStyle())
        }
        .padding(.horizontal, .themeSpacing16)
    }
}

struct WhatsNewView_Previews: PreviewProvider {
    static var previews: some View {
        WhatsNewView()
    }
}
