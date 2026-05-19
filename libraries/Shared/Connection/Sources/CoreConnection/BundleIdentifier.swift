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

public enum TunnelProtocol: Equatable, Hashable, Sendable {
    case ike
    case wireGuard(WGBackend)

    package static var availableProtocols: [Self] {
        #if os(macOS)
            [.ike, .wireGuard(.go), .wireGuard(.proTUN)]
        #else
            [.wireGuard(.go), .wireGuard(.proTUN)]
        #endif
    }

    /// Whether this protocol relies on app-side certificate authentication and a Local Agent connection.
    /// IKE (and eventually ProTUN V2) handle authentication natively in the tunnel extension.
    public var requiresLocalCertificateAuthentication: Bool {
        switch self {
        case .ike:
            false
        case .wireGuard:
            // With ProTUN V2, certificate auth will eventually be handled within the extension
            true
        }
    }
}

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
        static let wireGuardiOS = "ch.protonmail.vpn.WireGuardiOS-Extension"
        static let wireGuardiOSStaging = "ch.protonmail.vpn.debug.WireGuardiOS-Extension"
        static let proTUNiOS = "ch.protonmail.vpn.ProTUN-Extension-Mobile"
        static let proTUNiOSStaging = "ch.protonmail.vpn.debug.ProTUN-Extension-Mobile"
        static let wireGuardMac = "ch.protonvpn.mac.WireGuard-Extension"
        static let wireGuardtvOS = "ch.protonmail.vpn.WireGuard-tvOS"
    }

    package static let liveValue = BundleIDClient(
        bundleIdentifier: { proto in
            #if os(iOS)
                switch (proto, BuildType.buildType) {
                case (.wireGuard(.proTUN), .local):
                    return BundleID.proTUNiOS

                case (.wireGuard(.proTUN), .staging):
                    return BundleID.proTUNiOSStaging

                case (.wireGuard(.proTUN), .production):
                    fatalError("ProTUN is not available in production yet")

                case (.wireGuard(.go), .local), (.wireGuard(.go), .production):
                    return BundleID.wireGuardiOS

                case (.wireGuard(.go), .staging):
                    return BundleID.wireGuardiOSStaging

                case (.ike, _):
                    log.assertionFailure("IKE is not referenced through a bundle identifier.")
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
                    return [BundleID.wireGuardiOS]
                case .staging:
                    return [BundleID.wireGuardiOSStaging, BundleID.proTUNiOSStaging]
                case .local:
                    return [BundleID.wireGuardiOS, BundleID.proTUNiOS]
                }
            #elseif os(macOS)
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
            case BundleID.wireGuardiOS, BundleID.wireGuardiOSStaging:
                return .wireGuard(.go)

            case BundleID.wireGuardMac:
                return .wireGuard(.go)

            case BundleID.wireGuardtvOS:
                return .wireGuard(.go)

            case BundleID.proTUNiOS, BundleID.proTUNiOSStaging:
                return .wireGuard(.proTUN)

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
