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
import Theme

public extension BugReport.Colors {
    init() {
        self.init(
            primary: Theme.Asset.Colors.primary.color,
            interactive: Theme.Asset.Colors.interactionNorm.color,
            interactiveSecondary: Theme.Asset.Colors.interactionNormActive.color,
            interactiveActive: Theme.Asset.Colors.interactionNormHover.color,
            interactiveDisabled: Theme.Asset.Colors.interactionWeak.color,
            textPrimary: Theme.Asset.Colors.textNorm.color,
            textSecondary: Theme.Asset.Colors.textWeak.color,
            textAccent: Theme.Asset.Colors.textHint.color,
            background: Theme.Asset.Colors.backgroundNorm.color,
            backgroundWeak: Theme.Asset.Colors.backgroundWeak.color,
            backgroundStrong: Theme.Asset.Colors.backgroundStrong.color,
            backgroundUpdateButton: Theme.Asset.Colors.interactionWeak.color,
            separator: Theme.Asset.Colors.borderWeak.color,
            qfIcon: Theme.Asset.Colors.signalWarning.color,
            externalLinkIcon: Theme.Asset.Colors.textHint.color
        )
    }
}
