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
import SwiftUI

#if canImport(AppKit) && !targetEnvironment(macCatalyst)
    import AppKit

    /// The platform's color type, `NSColor` on macOS and `UIColor` elsewhere.
    public typealias PlatformColor = NSColor

    /// The palette `ThemeColor` names a color in. macOS and iOS have separate ones in ProtonCore.
    typealias ThemeColorPalette = ProtonColorPalettemacOS

    /// The appearance the palette resolves a color into, or `nil` when there is no running application.
    ///
    /// `ColorProvider` reads `NSApp.effectiveAppearance`, and `NSApp` is nil in a package test bundle,
    /// which has no `NSApplication`. Theme's own catalog colors need no appearance at all, so asking for
    /// one has to stay optional: a missing application is its own cache key rather than a crash.
    var themeAppearanceName: NSAppearance.Name? {
        NSApp?.effectiveAppearance.name
    }
#else
    import UIKit

    /// The platform's color type, `NSColor` on macOS and `UIColor` elsewhere.
    public typealias PlatformColor = UIColor

    /// The palette `ThemeColor` names a color in. macOS and iOS have separate ones in ProtonCore.
    typealias ThemeColorPalette = any ColorPaletteiOS
#endif

/// A color from ProtonCore's palette, named once here so no other module has to know where it lives.
///
/// Reading a palette color costs about 7 microseconds, because it looks the name up in a compiled
/// asset catalogue and then converts it to the appearance the app draws in, so the answer is kept.
/// On macOS the conversion produces a color for one appearance, so the cache remembers which
/// appearance each entry came from and re-reads after the user switches. On iOS the catalogue hands
/// back a color that adapts to the trait collection by itself, so one entry per name is enough.
public struct ThemeColor: Hashable, Sendable {
    /// Which palette entry the color comes from. Doubles as part of the cache key, so it is `Hashable`.
    private let keyPath: KeyPath<ThemeColorPalette, ProtonColor> & Sendable

    /// Palette colors already read, keyed by name and, on macOS, by the appearance they were read in.
    private static let colors = ThemeAssetCache<Key, PlatformColor>()

    private struct Key: Hashable {
        let keyPath: KeyPath<ThemeColorPalette, ProtonColor>
        #if canImport(AppKit) && !targetEnvironment(macCatalyst)
            let appearance: NSAppearance.Name?
        #endif
    }

    // MARK: - Init

    init(_ keyPath: KeyPath<ThemeColorPalette, ProtonColor> & Sendable) {
        self.keyPath = keyPath
    }

    // MARK: - Public API

    /// The color as an `NSColor` on macOS and a `UIColor` elsewhere, read from the palette once.
    public var platformColor: PlatformColor {
        Self.colors.value(for: key) { _ in
            ColorProvider[dynamicMember: keyPath]
        }
    }

    /// The color as a SwiftUI color.
    public var color: Color {
        Color(platformColor)
    }

    /// The color as a `CGColor`, for the AppKit and UIKit layers that draw with one.
    public var cgColor: CGColor {
        platformColor.cgColor
    }

    private var key: Key {
        #if canImport(AppKit) && !targetEnvironment(macCatalyst)
            // `ColorProvider` resolves against `NSApp.effectiveAppearance`, so that belongs in the key.
            Key(keyPath: keyPath, appearance: themeAppearanceName)
        #else
            Key(keyPath: keyPath)
        #endif
    }
}

#if canImport(AppKit) && !targetEnvironment(macCatalyst)
    public extension ThemeColor {
        /// The color as an `NSColor`, read from the palette once.
        var nsColor: NSColor {
            platformColor
        }
    }
#else
    public extension ThemeColor {
        /// The color as a `UIColor`, read from the palette once.
        var uiColor: UIColor {
            platformColor
        }
    }
#endif
