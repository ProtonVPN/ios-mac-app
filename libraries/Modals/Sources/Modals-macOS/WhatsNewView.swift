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

    public var dismiss: () -> Void = { }

    var body: some View {
        VStack(spacing: .themeSpacing32) {
            Asset.welcomeToProtonVpn.swiftUIImage

            Text(Localizable.modalsWhatsNew)
                .themeFont(.title1(emphasised: true))
            VStack(alignment: .leading, spacing: .themeSpacing4) {
                HStack {
                    Text(Localizable.modalsFreeCountries)
                        .themeFont(.headline(emphasised: true))
                    Spacer(minLength: 0)
                }
                HStack {
                    Text(Localizable.modalsNewServers)
                        .themeFont(.body())
                        .foregroundColor(Color(.text, .weak))
                    Spacer(minLength: 0)
                }
            }
            VStack(alignment: .leading, spacing: .themeSpacing4) {
                HStack {
                    Text(Localizable.modalsServerSelection)
                        .themeFont(.headline(emphasised: true))
                    Spacer(minLength: 0)
                }
                HStack {
                    Text(Localizable.modalsServerCrowding)
                        .themeFont(.body())
                        .fixedSize(horizontal: false, vertical: true) // allow multiline
                        .foregroundColor(Color(.text, .weak))
                    Spacer(minLength: 0)
                }
            }
            Button {
                
                dismiss()
            } label: {
                Text(Localizable.gotIt)
            }
            .buttonStyle(PrimaryButtonStyle())
        }
        .frame(width: 400)
        .padding(.themeSpacing64)
        .preferredColorScheme(.dark)
        .presentedWindowStyle(.hiddenTitleBar)
    }
}

@available(macOS 12.0, *)
struct WhatsNewView_Previews: PreviewProvider {
    static var previews: some View {
        WhatsNewView()
            .previewLayout(.sizeThatFits)
    }
}
