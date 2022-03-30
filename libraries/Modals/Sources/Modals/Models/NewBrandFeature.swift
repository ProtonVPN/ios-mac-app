//
//  Created on 28/03/2022.
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

import Foundation

public struct NewBrandFeature {
    public let artImage: Image = Asset.newBrandBackground.image
    public let iconImage: Image = Asset.vpnMain.image
    public let title: String = LocalizedString.modalsNewBrandTitle
    public let subtitle: String = LocalizedString.modalsNewBrandSubtitle
    public let readMore: String = LocalizedString.modalsNewBrandReadMore
    public let cancel: String = LocalizedString.modalsNewBrandDismiss

    public init() { }
}
