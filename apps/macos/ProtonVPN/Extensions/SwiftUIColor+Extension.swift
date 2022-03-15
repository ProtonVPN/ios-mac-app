//
//  Created on 2022-03-10.
//
//  Copyright (c) 2022 Proton AG
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
import ProtonCore_UIFoundations

extension Color {
    static var brandColor: Color {
        ColorProvider.BrandNorm
    }

    static var brandLighten20Color: Color {
        ColorProvider.BrandLighten20
    }

    static var brandLighten40Color: Color {
        ColorProvider.BrandLighten40
    }

    static var brandDarken40Color: Color {
        ColorProvider.BrandDarken40
    }

    static var secondaryBackgroundColor: Color {
        ColorProvider.BackgroundSecondary
    }

    static var backgroundColor: Color {
        ColorProvider.BackgroundNorm
    }

    static var weakTextColor: Color {
        ColorProvider.TextWeak
    }

    static var weakInteractionColor: Color {
        ColorProvider.InteractionWeak
    }

    static var normalSeparatorColor: Color {
        ColorProvider.SeparatorNorm
    }

    static var notificationWarningColor: Color {
        ColorProvider.NotificationWarning
    }

    static var notificationOKColor: Color {
        ColorProvider.NotificationSuccess
    }

    static var normalTextColor: Color {
        ColorProvider.TextNorm
    }

    static var notificationErrorColor: Color {
        ColorProvider.NotificationError
    }
}
