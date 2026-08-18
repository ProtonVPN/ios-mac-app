//
//  Created on 10/08/2026 by Max Kupetskyi.
//
//  Copyright (c) 2026 Proton AG
//
//  Proton VPN is free software: you can redistribute it and/or modify
//  it under the terms of the GNU General Public License as published by
//  the Free Software Foundation, either version 3 of the License, or
//  (at your option) any later version.
//
//  Proton VPN is distributed in the hope that it will be useful,
//  but WITHOUT ANY WARRANTY; without even the implied warranty of
//  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
//  GNU General Public License for more details.
//
//  You should have received a copy of the GNU General Public License
//  along with Proton VPN.  If not, see <https://www.gnu.org/licenses/>.

import CoreGraphics
import Domain
import Theme

public extension ServerGroupInfo.Kind {
    /// The image a top-level row shows on its leading edge: the country's flag, or the gateway badge.
    /// Cities and states appear one level down, with a map pin instead, so they have none.
    var flag: ImageAsset.Image? {
        switch self {
        case let .country(countryCode):
            ImageAsset.Image.flag(countryCode: countryCode)
        case .gateway:
            Theme.Asset.Flags.gateway.image
        case .city, .state:
            nil
        }
    }

    var flagCornerRadius: CGFloat {
        isGateway ? 0 : .themeRadius4
    }
}
