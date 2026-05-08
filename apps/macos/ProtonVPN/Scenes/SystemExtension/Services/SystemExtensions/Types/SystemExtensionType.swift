//
//  Created on 28/04/2026 by Max Kupetskyi.
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

import Domain
import VPNAppCore

public enum SystemExtensionType: String, CaseIterable, Sendable, Equatable {
    case wireGuard = "ch.protonvpn.mac.WireGuard-Extension"
    case plutonium = "ch.protonvpn.mac.Transparent-Proxy"

    public var machServiceName: String {
        "\(DomainConstants.appIdentifierPrefix)group.\(rawValue)"
    }

    public var featureEnabled: Bool {
        switch self {
        case .wireGuard:
            true
        case .plutonium:
            VPNFeatureFlagType.plutoniumMacOS.enabled
        }
    }
}

extension SystemExtensionType {
    var tourFeature: SystemExtensionTourAlert.Feature {
        switch self {
        case .plutonium: .splitTunneling
        case .wireGuard: .wireguard
        }
    }
}
