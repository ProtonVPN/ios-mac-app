//
//  Created on 14/12/2023.
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

public enum Constants {
    public static let readableContentWidth: CGFloat = 672

    public static let maxHomeContentWidth: CGFloat = 736
    public static let maxAnnouncementBannerWidth: CGFloat = 500
    public static let settingsViewSize = CGSize(width: 752, height: 572)
    public static let settingsAddIPViewSize = CGSize(width: 500, height: 511)

    /// Number of free countries beyond the ones depicted by the flags in the
    /// "Auto-selected from" disclaimer in the home connection card.
    public static let additionalFreeCountryCount: Int = 2
}
