//
//  Created on 28/11/2024.
//
//  Copyright (c) 2024 Proton AG
//
//  ProtonVPN is free software: you can redistribute it and/or modify
//  it under the terms of the GNU General Public License as published by
//  the Free Software Foundation, either version 3 of the License, or
//  (at your option) any later version.
//
//  ProtonVPN is distributed in the hope that it will be useful,
//  but WITHOUT ANY WARRANTY; without even the implied warranty of
//  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
//  GNU General Public License for more details.
//
//  You should have received a copy of the GNU General Public License
//  along with ProtonVPN.  If not, see <https://www.gnu.org/licenses/>.

import Dependencies
import DependenciesMacros
import Foundation

import Domain
import ProtonCoreFeatureFlags

@DependencyClient
package struct BundleIDClient: Sendable {
    package let bundleIdentifierForTarget: @Sendable () -> String
}

enum BuildType {
    static var buildType: Self {
        #if DEBUG
            return isStagingBuild ? .staging : .local
        #else
            return .production
        #endif
    }

    case local
    case staging
    case production

    private static let isStagingBuild: Bool = Bundle.main.bundleIdentifier?.contains("debug") ?? false
}

extension BundleIDClient: DependencyKey {
    private static var protunFFEnabled: Bool {
        FeatureFlagsRepository.shared.isEnabled(VPNFeatureFlagType.protun, reloadValue: true)
    }

    package static let liveValue = BundleIDClient {
        #if os(iOS)
            switch (protunFFEnabled, BuildType.buildType) {
            case (_, .production):
                return "ch.protonmail.vpn.WireGuardiOS-Extension"
            case (true, .staging):
                return "ch.protonmail.vpn.debug.ProTUN-Extension-Mobile"
            case (false, .staging):
                return "ch.protonmail.vpn.debug.WireGuardiOS-Extension"
            case (true, .local):
                return "ch.protonmail.vpn.ProTUN-Extension-Mobile"
            case (false, .local):
                return "ch.protonmail.vpn.WireGuardiOS-Extension"
            }
        #elseif os(macOS)
            return "ch.protonvpn.mac.WireGuard-Extension"
        #elseif os(tvOS)
            return "ch.protonmail.vpn.WireGuard-tvOS"
        #else
            fatalError("Unsupported platform")
        #endif
    }

    package static func mock(bundleID: String) -> Self {
        BundleIDClient(bundleIdentifierForTarget: { bundleID })
    }

    public static let testValue = liveValue
}

package extension DependencyValues {
    var bundleIDClient: BundleIDClient {
        get { self[BundleIDClient.self] }
        set { self[BundleIDClient.self] = newValue }
    }
}
