//
//  Created on 21/05/2026.
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
import LocalAgentIPC

public extension IPCLASettingsPayload {
    private static let fallbackFeatures: VPNConnectionFeatures = .init(
        netshield: .off,
        vpnAccelerator: false,
        bouncing: nil,
        natType: .moderateNAT,
        safeMode: false,
        portForwarding: false
    )

    var toVPNConnectionFeatures: VPNConnectionFeatures {
        .init(
            netshield: netshield_level == .unset ? Self.fallbackFeatures.netshield : netShieldType,
            vpnAccelerator: vpn_accelerator == .unset ? Self.fallbackFeatures.vpnAccelerator : vpn_accelerator == .enabled,
            bouncing: nil,
            natType: random_nat == .unset ? Self.fallbackFeatures.natType : NATType(flag: random_nat == .strict),
            safeMode: soft_jail == .unset ? Self.fallbackFeatures.safeMode : soft_jail == .enabled,
            portForwarding: port_forwarding == .unset ? Self.fallbackFeatures.portForwarding : port_forwarding == .enabled
        )
    }

    /// True if the extension has written at least one field.
    /// Guards against treating a freshly-created (all-zero) mmap region as meaningful settings.
    var hasValues: Bool {
        netshield_level != .unset
            || vpn_accelerator != .unset
            || port_forwarding != .unset
            || random_nat != .unset
            || soft_jail != .unset
            || circumvention_routing != .unset
    }

    private var netShieldType: NetShieldType {
        switch netshield_level {
        case .malware: .level1
        case .adsAndMalware: .level2
        default: .off
        }
    }

    init(_ features: VPNConnectionFeatures) {
        self = .init(
            netshield_level: features.netshield.toNetshieldLevel,
            vpn_accelerator: features.vpnAccelerator ? .enabled : .disabled,
            port_forwarding: features.portForwarding.map { $0 ? .enabled : .disabled } ?? .unset,
            random_nat: features.natType.flag ? .strict : .moderate,
            soft_jail: features.safeMode.map { $0 ? .enabled : .disabled } ?? .unset,
            circumvention_routing: .unset
        )
    }
}

private extension NetShieldType {
    var toNetshieldLevel: IPCLANetshieldLevel {
        switch self {
        case .off: .off
        case .level1: .malware
        case .level2: .adsAndMalware
        case .level3: .adultContentAndAdsAndMalware
        }
    }
}
