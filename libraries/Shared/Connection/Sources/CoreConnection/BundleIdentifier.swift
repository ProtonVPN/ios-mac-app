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
import Domain
import Foundation
import class NetworkExtension.NETunnelProviderProtocol
import class NetworkExtension.NEVPNProtocol
import VPNAppCore

@DependencyClient
package struct BundleIDClient {
    package private(set) var bundleIdentifier: @Sendable (_ protocol: TunnelProtocol) -> String = { _ in "" }
    package private(set) var allBundleIdentifiers: @Sendable () -> [String] = { [] }
    package private(set) var tunnelProtocol: @Sendable (_ configuration: NEVPNProtocol) -> TunnelProtocol?
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
    private enum BundleID {
        static let proTUNiOS = "ch.protonmail.vpn.WireGuardiOS-Extension"
        static let proTUNiOSStaging = "ch.protonmail.vpn.debug.WireGuardiOS-Extension"
        static let wireGuardMac = "ch.protonvpn.mac.WireGuard-Extension"
        static let plutoniumMac = "ch.protonvpn.mac.Transparent-Proxy"
        static let wireGuardtvOS = "ch.protonmail.vpn.WireGuard-tvOS"

        /// In development, we used distinct bundle identifiers for ProTUN targets.
        /// However, we are locked in to using the old `WireGuardiOS-Extension` identifiers due to these being
        /// already pre-approved on users' systems.
        /// static let legacyProTUNiOS = "ch.protonmail.vpn.ProTUN-Extension-Mobile"
        /// static let legacyProTUNiOSStaging = "ch.protonmail.vpn.debug.ProTUN-Extension-Mobile"
    }

    package static let liveValue = BundleIDClient(
        bundleIdentifier: { proto in
            #if os(iOS)
                switch (proto, BuildType.buildType) {
                case (.wireGuard(.proTUN), .local), (.wireGuard(.proTUN), .production):
                    return BundleID.proTUNiOS

                case (.wireGuard(.proTUN), .staging):
                    return BundleID.proTUNiOSStaging

                case (.ike, _):
                    log.assertionFailure("IKE is not referenced through a bundle identifier.")
                    return ""

                case (.wireGuard(.go), _):
                    log.assertionFailure("WireGuard Go has been deprecated")
                    return ""
                }
            #elseif os(macOS)
                return BundleID.wireGuardMac
            #elseif os(tvOS)
                return BundleID.wireGuardtvOS
            #endif
        },
        allBundleIdentifiers: {
            #if os(iOS)
                switch BuildType.buildType {
                case .production:
                    return [BundleID.proTUNiOS]
                case .staging:
                    return [BundleID.proTUNiOS, BundleID.proTUNiOSStaging]
                case .local:
                    return [BundleID.proTUNiOS, BundleID.proTUNiOSStaging]
                }
            #elseif os(macOS)
                // Transparent Proxy must not be treated as a regular VPN tunnel provider manager.
                // Keeping only WireGuard here avoids manager key collisions in repository caches keyed by TunnelProtocol.
                return [BundleID.wireGuardMac]
            #elseif os(tvOS)
                return [BundleID.wireGuardtvOS]
            #endif
        },
        tunnelProtocol: { configuration in
            guard let bundleIdentifier = (configuration as? NETunnelProviderProtocol)?.providerBundleIdentifier else {
                return .ike
            }
            switch bundleIdentifier {
            case BundleID.proTUNiOS, BundleID.proTUNiOSStaging:
                return .wireGuard(.proTUN)

            case BundleID.wireGuardMac:
                return .wireGuard(.proTUN)

            case BundleID.wireGuardtvOS:
                return .wireGuard(.proTUN)

            case BundleID.plutoniumMac:
                // Transparent Proxy notifications can be observed via shared NEVPN notifications.
                // Keep it separate from core tunnel protocol mapping to avoid manager collisions.
                return nil

            default:
                SentryHelper.shared?.log(message: "Encountered unknown bundle identifier", extra: ["bundleIdentifier": bundleIdentifier])
                return nil
            }
        }
    )

    package static func mock(bundleID: String, allBundleIDs: [String]? = nil) -> Self {
        BundleIDClient(
            bundleIdentifier: { _ in bundleID },
            allBundleIdentifiers: { allBundleIDs ?? [bundleID] },
            tunnelProtocol: { _ in .wireGuard(.go) }
        )
    }

    public static let testValue = liveValue
}

package extension DependencyValues {
    var bundleIDClient: BundleIDClient {
        get { self[BundleIDClient.self] }
        set { self[BundleIDClient.self] = newValue }
    }
}
