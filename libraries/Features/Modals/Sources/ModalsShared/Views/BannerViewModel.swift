//
//  Created on 2023-08-29.
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

import Foundation
import Strings

public struct BannerViewModel {
    var leftIcon: ImageAsset
    var text: String
    var action: () -> Void

    public init(leftIcon: ImageAsset, text: String, action: @escaping () -> Void) {
        self.leftIcon = leftIcon
        self.text = text
        self.action = action
    }
}

#if DEBUG
    public extension BannerViewModel {
        static let upsellBanner = BannerViewModel(
            leftIcon: Asset.worldwideCoverage,
            text: Localizable.freeBannerText,
            action: {}
        )

        static let shortText = BannerViewModel(
            leftIcon: Asset.getStarted,
            text: "Upgrade to unlock faster speeds",
            action: {}
        )

        static let longText = BannerViewModel(
            leftIcon: Asset.maximumDeviceLimitUpsell,
            text: "Connect unlimited devices with VPN Plus and protect your entire household",
            action: {}
        )

        static let customIcon = BannerViewModel(
            leftIcon: Asset.worldwideCoverage,
            text: "Block ads, trackers and malware with NetShield",
            action: {}
        )
    }
#endif
