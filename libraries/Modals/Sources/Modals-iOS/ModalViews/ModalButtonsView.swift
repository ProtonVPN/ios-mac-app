//
//  Created on 13/12/2023.
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

import Modals
import SwiftUI
import SharedViews

struct ModalButtonsView: View {
    let modalModel: ModalModel

    var primaryAction: (() -> Void)?
    var dismissAction: (() -> Void)?

    var body: some View {
        VStack {
            if let primaryAction {
                Button(action: primaryAction) {
                    Text(modalModel.primaryButtonTitle)
                }
                .buttonStyle(PrimaryButtonStyle())
            }
            if let dismissAction, let title = modalModel.secondaryButtonTitle {
                Button(action: dismissAction) {
                    Text(title)
                }
                .buttonStyle(SecondaryButtonStyle())
            }
        }
    }
}

struct ModalButtons_Previews: PreviewProvider {
    static var previews: some View {
        ModalButtonsView(modalModel: ModalType.safeMode.modalModel(),
                         primaryAction: { },
                         dismissAction: { })
            .previewDisplayName("ModalButtons")
    }
}
