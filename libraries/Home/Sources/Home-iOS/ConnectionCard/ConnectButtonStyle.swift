//
//  Created on 27/08/2024.
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
import Theme

struct ConnectButtonStyle: ButtonStyle {

    var isDisconnected = true

    func makeBody(configuration: Configuration) -> some View {
        let style: AppTheme.Style

        switch (isDisconnected, configuration.isPressed) {
        case (false, false):
            /* Button reads "disconnect" or "cancel" */
            style = [.interactive, .weak]
        case (false, true):
            /* Button reads "disconnect" or "cancel" and is pressed */
            style = [.weak]
        case (true, false):
            /* Button reads "connect" */
            style = [.interactive]
        case (true, true):
            /* Button reads "connect" and is pressed */
            style = [.interactive, .active]
        }

        return configuration.label
            .font(.body1(.semibold))
            .frame(maxWidth: .infinity, minHeight: 48)
            .foregroundColor(Color(.text, .primary))
            .background(Color(.background, style))
            .cornerRadius(.themeRadius8)
    }
}
