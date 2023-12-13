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
import Modals
import ProtonCoreUIFoundations

struct ModalView: View {

    let upsellType: UpsellType

    private static let maxContentWidth: CGFloat = 480

    var primaryAction: (() -> Void)?
    var dismissAction: (() -> Void)?

    var body: some View {
        UpsellBackgroundView(showGradient: upsellType.shouldAddGradient()) {
            VStack(spacing: .themeSpacing16) {
                ModalBodyView(upsellType: upsellType)
                ModalButtonsView(upsellType: upsellType, 
                                 primaryAction: primaryAction,
                                 dismissAction: dismissAction)
            }
            .padding(.horizontal, .themeSpacing16)
            .padding(.bottom, .themeRadius16)
            .frame(maxWidth: Self.maxContentWidth)
        }
        .background(Color(.background))
    }
}

struct ModalView_Previews: PreviewProvider {
    static var previews: some View {
        ModalView(upsellType: .welcomePlus(numberOfServers: 1800,
                                           numberOfDevices: 10,
                                           numberOfCountries: 68))
        .previewDisplayName("Welcome plus")

        ModalView(upsellType: .welcomeUnlimited)
        .previewDisplayName("Welcome unlimited")
    }
}
