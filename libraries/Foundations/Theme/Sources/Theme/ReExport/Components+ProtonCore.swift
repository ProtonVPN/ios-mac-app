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

#if os(iOS)
    import ProtonCoreUIFoundations

    // The two ProtonCore views the app still uses directly. They are named here so Theme stays the
    // only module that imports ProtonCoreUIFoundations.

    /// ProtonCore's banner, shown over the top of the screen.
    public typealias ProtonBanner = PMBanner

    /// The styles `ProtonBanner` can take.
    public typealias ProtonBannerStyle = PMBannerNewStyle

    /// ProtonCore's button, used by the account cards in Settings.
    public typealias ProtonCoreButton = PCButton
#endif
