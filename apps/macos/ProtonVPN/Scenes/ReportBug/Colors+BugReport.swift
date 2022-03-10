//
//  Created on 2022-02-10.
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

import BugReport
import SwiftUI

@available(macOS 11, *)
extension BugReport.Colors {
    public init() {
        self.init(brand: .brandColor,
                  brandLight20: .brandLighten20Color,
                  brandLight40: .brandLighten40Color,
                  brandDark40: .brandDarken40Color,
                  textPrimary: .normalTextColor,
                  textSecondary: .weakTextColor,
                  background: .backgroundColor,
                  backgroundSecondary: .secondaryBackgroundColor,
                  backgroundUpdateButton: .weakInteractionColor,
                  separator: .normalSeparatorColor,
                  qfIcon: .notificationWarningColor
        )
    }
}
