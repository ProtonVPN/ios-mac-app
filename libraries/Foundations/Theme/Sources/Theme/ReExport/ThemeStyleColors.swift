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

import Foundation

#if canImport(AppKit) && !targetEnvironment(macCatalyst)
    import AppKit
#endif

/// The color the theme picks for a context and style pair, worked out once per pair.
///
/// Picking one costs about 22 microseconds, because every branch of `AppTheme.Style` reads a named
/// color from an asset catalogue and macOS then converts it to the current appearance. A pair is picked once and remembered after that.
enum ThemeStyleColors {
    private static let colors = ThemeAssetCache<Key, PlatformColor>()

    private struct Key: Hashable {
        let context: AppTheme.Context
        let style: AppTheme.Style
        #if canImport(AppKit) && !targetEnvironment(macCatalyst)
            /// macOS resolves a palette color into one appearance, so entries cannot be shared across them.
            let appearance: NSAppearance.Name?
        #endif
    }

    /// The color for `context` and `style`, calling `pick` only the first time that pair comes up.
    static func color(
        context: AppTheme.Context,
        style: AppTheme.Style,
        pick: () -> PlatformColor
    ) -> PlatformColor {
        colors.value(for: key(context: context, style: style)) { _ in pick() }
    }

    private static func key(context: AppTheme.Context, style: AppTheme.Style) -> Key {
        #if canImport(AppKit) && !targetEnvironment(macCatalyst)
            // The palette resolves against `NSApp.effectiveAppearance`, so that belongs in the key. Many
            // styles never reach the palette, though: they come from Theme's own catalog, which needs no
            // appearance and no application, so this must not insist on one.
            Key(context: context, style: style, appearance: themeAppearanceName)
        #else
            Key(context: context, style: style)
        #endif
    }
}
