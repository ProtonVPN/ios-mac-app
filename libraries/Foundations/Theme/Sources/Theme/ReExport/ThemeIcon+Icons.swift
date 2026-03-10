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

public struct ThemeIcon: Equatable, Sendable {
    private enum Source: Equatable, Sendable {
        /// An icon resolved from Theme's internal asset catalogue.
        case asset(String)
        /// An icon resolved via `IconProvider` from ProtonCoreUIFoundations.
        case iconProvider(KeyPath<ProtonIconSet, ProtonIcon> & Sendable)
    }

    private let source: Source

    // MARK: - Init

    init(asset: ImageAsset) {
        self.source = .asset(asset.name)
    }

    init(iconProviderKeyPath keyPath: KeyPath<ProtonIconSet, ProtonIcon> & Sendable) {
        self.source = .iconProvider(keyPath)
    }

    // MARK: - Public API

    public var swiftUIImage: Image {
        switch source {
        case let .asset(name):
            Image(name, bundle: .module)
        case let .iconProvider(keyPath):
            IconProvider[dynamicMember: keyPath]
        }
    }

    public var image: ImageAsset.Image {
        switch source {
        case let .asset(name):
            if name == Asset.vpnSubscriptionBadge.name {
                return Asset.vpnSubscriptionBadge.image
            }
            fatalError("image is not available for asset-backed ThemeIcon '\(name)'.")
        case let .iconProvider(keyPath):
            return IconProvider[dynamicMember: keyPath]
        }
    }
}
