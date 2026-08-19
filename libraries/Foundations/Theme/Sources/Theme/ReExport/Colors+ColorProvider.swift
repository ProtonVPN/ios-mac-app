//
//  Created on 05/08/2026 by Max Kupetskyi.
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

/// The colors from ProtonCore's palette that the app names directly.
public extension Asset {
    enum Colors {
        /// The adaptive shade 40 color.
        public static let shade40 = ThemeColor(\.Shade40)

        // MARK: - Profile colors

        /// The colors a user can pick for a profile, in the order the color picker shows them.
        public static let profileColors: [PlatformColor] = [
            purpleBase, pinkBase, strawberryBase, carrotBase, saharaBase,
            slateblueBase, pacificBase, reefBase, fernBase, oliveBase,
        ].map(\.platformColor)

        public static let purpleBase = ThemeColor(\.PurpleBase)
        public static let pinkBase = ThemeColor(\.PinkBase)
        public static let strawberryBase = ThemeColor(\.StrawberryBase)
        public static let carrotBase = ThemeColor(\.CarrotBase)
        public static let saharaBase = ThemeColor(\.SaharaBase)
        public static let slateblueBase = ThemeColor(\.SlateblueBase)
        public static let pacificBase = ThemeColor(\.PacificBase)
        public static let reefBase = ThemeColor(\.ReefBase)
        public static let fernBase = ThemeColor(\.FernBase)
        public static let oliveBase = ThemeColor(\.OliveBase)

        // MARK: - Colors both palettes carry

        public static let backgroundNorm = ThemeColor(\.BackgroundNorm)
        public static let interactionNorm = ThemeColor(\.InteractionNorm)
        public static let interactionWeak = ThemeColor(\.InteractionWeak)
        public static let textHint = ThemeColor(\.TextHint)
        public static let textNorm = ThemeColor(\.TextNorm)
        public static let textWeak = ThemeColor(\.TextWeak)
        public static let white = ThemeColor(\.White)
    }
}

#if canImport(AppKit) && !targetEnvironment(macCatalyst)
    public extension Asset.Colors {
        // MARK: - Colors only the macOS palette carries

        static let backgroundStrong = ThemeColor(\.BackgroundStrong)
        static let backgroundWeak = ThemeColor(\.BackgroundWeak)
        static let borderWeak = ThemeColor(\.BorderWeak)
        static let interactionNormActive = ThemeColor(\.InteractionNormActive)
        static let interactionNormHover = ThemeColor(\.InteractionNormHover)
        static let primary = ThemeColor(\.Primary)
        static let signalWarning = ThemeColor(\.SignalWarning)
    }
#else
    public extension Asset.Colors {
        // MARK: - Colors only the iOS palette carries

        static let backgroundSecondary = ThemeColor(\.BackgroundSecondary)
        static let brandDarken40 = ThemeColor(\.BrandDarken40)
        static let brandLighten20 = ThemeColor(\.BrandLighten20)
        static let brandLighten40 = ThemeColor(\.BrandLighten40)
        static let brandNorm = ThemeColor(\.BrandNorm)
        static let iconAccent = ThemeColor(\.IconAccent)
        static let iconHint = ThemeColor(\.IconHint)
        static let iconNorm = ThemeColor(\.IconNorm)
        static let iconWeak = ThemeColor(\.IconWeak)
        static let notificationError = ThemeColor(\.NotificationError)
        static let notificationSuccess = ThemeColor(\.NotificationSuccess)
        static let notificationWarning = ThemeColor(\.NotificationWarning)
        static let separatorNorm = ThemeColor(\.SeparatorNorm)
        static let textAccent = ThemeColor(\.TextAccent)
    }
#endif
