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

struct ModalView: View {
    private static let maxContentWidth: CGFloat = 480

    let modalType: ModalType
    let modalModel: ModalModel

    private let primaryAction: (() -> Void)?
    private let dismissAction: (() -> Void)?

    init(modalType: ModalType, primaryAction: (() -> Void)? = nil, dismissAction: (() -> Void)? = nil) {
        self.modalType = modalType
        self.modalModel = modalType.modalModel()
        self.primaryAction = primaryAction
        self.dismissAction = dismissAction
    }

    var body: some View {
        UpsellBackgroundView(showGradient: modalModel.shouldAddGradient) {
            VStack(spacing: .themeSpacing16) {
                ModalBodyView(modalType: modalType)
                ModalButtonsView(modalModel: modalModel,
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

#if swift(>=5.9)
#Preview("Welcome plus") {
    ModalView(modalType: .welcomePlus(
        numberOfServers: 1800,
        numberOfDevices: 10,
        numberOfCountries: 68
    ))
}

#Preview("Welcome unlimited") {
    ModalView(modalType: .welcomeUnlimited)
        .previewDisplayName("Welcome unlimited")
}
#else
struct ModalView_Previews: PreviewProvider {
    static var previews: some View {
        ModalView(modalType: .welcomePlus(
            numberOfServers: 1800,
            numberOfDevices: 10,
            numberOfCountries: 68
        )).previewDisplayName("Welcome plus")

        ModalView(modalType: .welcomeUnlimited)
            .previewDisplayName("Welcome unlimited")
    }
}
#endif
