//
//  Created on 07/05/2023.
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

import vpncore
import SwiftUI
import Theme

enum SideBarTab: Hashable, CaseIterable {
    case home
    case countries
    case settings

    var title: String {
        switch self {
        case .home:
            return LocalizedString.home
        case .countries:
            return LocalizedString.countries
        case .settings:
            return LocalizedString.settings
        }
    }

    var image: SwiftUI.Image {
        switch self {
        case .home:
            return Asset.icHouse.swiftUIImage
        case .countries:
            return Asset.icEarth.swiftUIImage
        case .settings:
            return Asset.icCogWheel.swiftUIImage
        }
    }
}
