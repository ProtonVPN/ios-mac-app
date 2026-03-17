//
//  Created on 27/02/2026 by Max Kupetskyi.
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

public extension Asset {
    /// The VPN subscription badge from Theme's own asset catalogue, as a `ThemeIcon`.
    static let vpnSubscriptionBadgeIcon = ThemeIcon(asset: vpnSubscriptionBadge)

    enum Icons {
        // ProtonCoreUI icons
        public static let alias = ThemeIcon(iconProviderKeyPath: \.alias)
        public static let arrowsLeftRight = ThemeIcon(iconProviderKeyPath: \.arrowsLeftRight)
        public static let arrowOutSquare = ThemeIcon(iconProviderKeyPath: \.arrowOutSquare)
        public static let arrowsSwitch = ThemeIcon(iconProviderKeyPath: \.arrowsSwitch)
        public static let bolt = ThemeIcon(iconProviderKeyPath: \.bolt)
        public static let brandTor = ThemeIcon(iconProviderKeyPath: \.brandTor)
        public static let chartLine = ThemeIcon(iconProviderKeyPath: \.chartLine)
        public static let chevronDownFilled = ThemeIcon(iconProviderKeyPath: \.chevronDownFilled)
        public static let circleSlash = ThemeIcon(iconProviderKeyPath: \.circleSlash)
        public static let powerOff = ThemeIcon(iconProviderKeyPath: \.powerOff)
        public static let crossBig = ThemeIcon(iconProviderKeyPath: \.crossBig)
        public static let globe = ThemeIcon(iconProviderKeyPath: \.globe)
        public static let infoCircle = ThemeIcon(iconProviderKeyPath: \.infoCircle)
        public static let infoCircleFilled = ThemeIcon(iconProviderKeyPath: \.infoCircleFilled)
        public static let lockOpen = ThemeIcon(iconProviderKeyPath: \.lockOpen)
        public static let locks = ThemeIcon(iconProviderKeyPath: \.locks)
        public static let magicWand = ThemeIcon(iconProviderKeyPath: \.magicWand)
        public static let magnifier = ThemeIcon(iconProviderKeyPath: \.magnifier)
        public static let mapPin = ThemeIcon(iconProviderKeyPath: \.mapPin)
        public static let play = ThemeIcon(iconProviderKeyPath: \.play)
        public static let printer = ThemeIcon(iconProviderKeyPath: \.printer)
        public static let rocket = ThemeIcon(iconProviderKeyPath: \.rocket)
        public static let servers = ThemeIcon(iconProviderKeyPath: \.servers)
        public static let shield = ThemeIcon(iconProviderKeyPath: \.shield)
        public static let shieldFilled = ThemeIcon(iconProviderKeyPath: \.shieldFilled)
        public static let sliders = ThemeIcon(iconProviderKeyPath: \.sliders)
        public static let threeDotsVertical = ThemeIcon(iconProviderKeyPath: \.threeDotsVertical)
        public static let wrench = ThemeIcon(iconProviderKeyPath: \.wrench)
    }
}
