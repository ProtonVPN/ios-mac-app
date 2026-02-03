//
//  Created on 25.07.2025 by John Biggs.
//
//  Copyright (c) 2025 Proton AG
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
import ProtonCoreFeatureFlags
import ProtonCoreServices

/// A wrapper around FeatureFlagsRepository that tracks whether fetchFlags() has been called
/// and asserts if isEnabled() is used before initialization.
public final class CheckedFeatureFlagsRepository {
    public static let shared = CheckedFeatureFlagsRepository()

    private static let flagsFetchingTimeoutDuration: Duration = .seconds(5)

    private var _hasFetchedFlags: UInt32 = 0
    private let repository = FeatureFlagsRepository.shared

    public func setApiService(_ apiService: any APIService) {
        repository.setApiService(apiService)
    }

    // We should move to Atomic<Bool> once our minimum deployment target is iOS 18 or later.
    // OSAtomic* functions were deprecated in iOS 10.
    public func fetchFlags() async {
        try? await withTimeout(of: Self.flagsFetchingTimeoutDuration) { try? await self.repository.fetchFlags() }
        OSAtomicCompareAndSwap32(0, 1, &_hasFetchedFlags)
    }

    public var hasFetchedFlags: Bool {
        OSAtomicCompareAndSwap32(1, 1, &_hasFetchedFlags)
    }

    /// Safe wrapper around FeatureFlagsRepository.shared.isEnabled() that asserts if called before fetchFlags()
    public func isEnabled(_ flag: any FeatureFlagTypeProtocol, reloadValue: Bool = false) -> Bool {
        // assert(hasFetchedFlags, "Should not call isEnabled() before loading flags")
        repository.isEnabled(flag, reloadValue: reloadValue)
    }
}

public extension FeatureFlagTypeProtocol {
    var enabled: Bool {
        CheckedFeatureFlagsRepository.shared.isEnabled(self)
    }
}
