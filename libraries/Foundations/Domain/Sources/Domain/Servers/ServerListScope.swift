//
//  Created on 21/08/2026 by Max Kupetskyi.
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

public enum ServerListScope: Sendable, Equatable, CaseIterable {
    case allTiers
    case freeTier
    case guestSession

    public var isCappedAtFreeTier: Bool {
        self == .freeTier
    }

    public var coversEveryTier: Bool {
        self != .freeTier
    }

    /// The same scope, never capped at the free tier.
    ///
    /// A guest request already asks for every tier, so only a free tier request widens.
    public var coveringEveryTier: Self {
        self == .freeTier ? .allTiers : self
    }
}
