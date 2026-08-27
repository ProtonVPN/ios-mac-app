//
//  Created on 19/08/2026 by Max Kupetskyi.
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

import ProtonCoreUIFoundations

public extension AppTheme {
    /// Points ProtonCore's palette and icon set at the VPN brand.
    ///
    /// ProtonCore ships one set of assets per Proton app and picks between them by brand, so this
    /// belongs in app start-up. Colors and icons read before the call are thrown away, so calling it
    /// after something has already drawn is safe.
    static func useVPNBrand() {
        ColorProvider.brand = .vpn
        ThemeAssetCaches.removeAllValues()
    }
}
