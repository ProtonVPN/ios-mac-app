//
//  Created on 09.08.23.
//
//  Copyright (c) 2023 Proton AG
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
//  along with Proton VPN.  If not, see <https://www.gnu.org/licenses/>.

import Dependencies
import Foundation

/// Detects local network interfaces whose IPv4 ranges fall outside the RFC1918 / RFC3927
/// "local" ranges. When the OS sees a "local-looking" IP that's actually routable on the WAN,
/// it can leak traffic around the VPN tunnel unless Kill Switch is enabled.
///
/// This is a pure detection helper — the caller decides whether to surface the result
/// to the user (e.g. as a warning alert) and how to react.
///
/// Replaces the legacy `MisconfiguredLocalNetworkIntercept` which directly coupled
/// detection with `CoreAlertService`.
public struct MisconfiguredLanInspector: Sendable {
    /// Returns the first interface with a "bad" subnet, or `nil` if all interfaces look fine.
    public var firstBadInterface: @Sendable () -> BadLanInterface?

    public init(firstBadInterface: @escaping @Sendable () -> BadLanInterface?) {
        self.firstBadInterface = firstBadInterface
    }
}

/// User-facing summary of a misconfigured network interface.
public struct BadLanInterface: Equatable, Sendable {
    public let name: String?
    public let subnetDescription: String?

    public init(name: String?, subnetDescription: String?) {
        self.name = name
        self.subnetDescription = subnetDescription
    }
}

extension MisconfiguredLanInspector: DependencyKey {
    public static let liveValue = MisconfiguredLanInspector(
        firstBadInterface: {
            @Dependency(\.networkInterfacePropertiesProvider) var interfacePropertiesProvider
            do {
                let interfaces = try interfacePropertiesProvider.withNetworkInterfaceInfo()
                guard let bad = interfaces.first(where: \.hasBadRanges) else { return nil }
                return BadLanInterface(name: bad.name, subnetDescription: bad.ipv4SubnetDescription)
            } catch {
                return nil
            }
        }
    )

    public static let testValue = MisconfiguredLanInspector(firstBadInterface: { nil })
}

public extension DependencyValues {
    var misconfiguredLanInspector: MisconfiguredLanInspector {
        get { self[MisconfiguredLanInspector.self] }
        set { self[MisconfiguredLanInspector.self] = newValue }
    }
}
