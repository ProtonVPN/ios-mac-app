//
//  Created on 15.07.2026 by John Biggs.
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

import Dependencies
import IssueReporting
import ProtonCoreFeatureFlags

/// Controlled access to feature flags, backing `FeatureFlagTypeProtocol.enabled`.
///
/// The live value consults `CheckedFeatureFlagsRepository`, so app code keeps the
/// flags-fetched-before-read assertion. Tests get an unimplemented client that records an issue for
/// any flag they consult without declaring it, and override the flags they rely on:
///
/// ```swift
/// withDependencies {
///     $0.featureFlags = .enabling(VPNFeatureFlagType.timestampedLogicals)
/// } operation: {
///     ...
/// }
/// ```
public struct FeatureFlagsClient: Sendable {
    public var isEnabled: @Sendable (any FeatureFlagTypeProtocol) -> Bool

    public init(isEnabled: @escaping @Sendable (any FeatureFlagTypeProtocol) -> Bool) {
        self.isEnabled = isEnabled
    }
}

extension FeatureFlagsClient: DependencyKey {
    public static var liveValue: FeatureFlagsClient {
        FeatureFlagsClient { CheckedFeatureFlagsRepository.shared.isEnabled($0) }
    }

    public static var testValue: FeatureFlagsClient {
        FeatureFlagsClient(isEnabled: unimplemented("FeatureFlagsClient.isEnabled", placeholder: false))
    }

    public static var previewValue: FeatureFlagsClient {
        FeatureFlagsClient { _ in false }
    }
}

public extension FeatureFlagsClient {
    /// A client answering `true` for exactly the given flags and `false` for every other.
    static func enabling(_ flags: (any FeatureFlagTypeProtocol)...) -> FeatureFlagsClient {
        // Collected with a loop on purpose. Folding this into `map(\.rawValue)` crashes the
        // Swift 6.3.1 frontend: SILGen cannot lower a key-path literal over the existential
        // flag type. Keep the loop until a fixed toolchain ships.
        var enabledFlagNames = Set<String>()
        for flag in flags {
            enabledFlagNames.insert(flag.rawValue)
        }
        return FeatureFlagsClient { enabledFlagNames.contains($0.rawValue) }
    }
}

public extension DependencyValues {
    var featureFlags: FeatureFlagsClient {
        get { self[FeatureFlagsClient.self] }
        set { self[FeatureFlagsClient.self] = newValue }
    }
}
