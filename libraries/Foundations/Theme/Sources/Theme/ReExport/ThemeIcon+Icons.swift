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
import SwiftUI

/// An icon the app can draw, named once here so no other module has to know which catalogue holds it.
///
/// Both catalogues are read through CoreUI, which costs about 38 microseconds per read on macOS and hands back
/// a new image each time, so `image` keeps what it resolved.
public struct ThemeIcon: Equatable, Sendable {
    /// Which catalogue holds the icon. Doubles as the cache key, so it is `Hashable`.
    fileprivate enum Source: Hashable {
        /// An icon resolved from Theme's own asset catalogue.
        case asset(String)
        /// An icon resolved via `IconProvider` from ProtonCoreUIFoundations.
        case iconProvider(KeyPath<ProtonIconSet, ProtonIcon> & Sendable)
    }

    private let source: Source

    /// Icons already read from a catalogue, so each one is read once per process.
    private static let images = ThemeAssetCache<Source, ImageAsset.Image>()

    // MARK: - Init

    public init(asset: ImageAsset) {
        self.source = .asset(asset.name)
    }

    init(iconProviderKeyPath keyPath: KeyPath<ProtonIconSet, ProtonIcon> & Sendable) {
        self.source = .iconProvider(keyPath)
    }

    // MARK: - Public API

    /// The icon as a SwiftUI image.
    ///
    /// This one is not cached because it only names the image, at about 0.08 microseconds. SwiftUI
    /// reads the catalogue itself when it draws, and caches that.
    public var swiftUIImage: Image {
        switch source {
        case let .asset(name):
            Image(name, bundle: .module)
        case let .iconProvider(keyPath):
            IconProvider[dynamicMember: keyPath]
        }
    }

    /// The icon as an `NSImage` on macOS and a `UIImage` elsewhere, read from the catalogue once.
    public var image: ImageAsset.Image {
        Self.images.value(for: source) { source in
            switch source {
            case let .asset(name):
                Self.assetCatalogImage(named: name)
            case let .iconProvider(keyPath):
                IconProvider[dynamicMember: keyPath]
            }
        }
    }

    // MARK: - Reading Theme's own catalogue

    /// The named image from Theme's asset catalogue, or an empty image when the name is unknown.
    ///
    /// An unknown name means the catalogue and this file disagree, which is a programmer error, so it
    /// trips an assertion in debug builds and draws nothing in release builds.
    private static func assetCatalogImage(named name: String) -> ImageAsset.Image {
        #if canImport(AppKit) && !targetEnvironment(macCatalyst)
            let image = Bundle.module.image(forResource: NSImage.Name(name))
        #else
            let image = ImageAsset.Image(named: name, in: .module, compatibleWith: nil)
        #endif
        guard let image else {
            log.assertionFailure("Theme's asset catalogue has no image named \(name)")
            return ImageAsset.Image()
        }
        return image
    }
}
