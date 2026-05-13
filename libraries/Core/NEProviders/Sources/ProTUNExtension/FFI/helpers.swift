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

#if os(iOS) && DEBUG
    import Domain
    import LocalAgent
    import LocalAgentIPC

    extension NetshieldLevel {
        var toNetShieldType: NetShieldType {
            switch self {
            case .none: .off
            case .malwareFilter: .level1
            case .adsAndMalwareFilter: .level2
            }
        }

        var toPayload: IPCLANetshieldLevel {
            switch self {
            case .none: .off
            case .malwareFilter: .malware
            case .adsAndMalwareFilter: .adsAndMalware
            }
        }
    }

    extension LocalAgentSettingType: CustomStringConvertible {
        public var description: String {
            switch self {
            case .netshieldLevel:
                "netshieldLevel"
            case .bouncing:
                "bouncing"
            case .portForwarding:
                "portForwarding"
            case .splitTcp:
                "splitTcp"
            case .safeMode:
                "safeMode"
            case .randomNat:
                "randomNat"
            }
        }
    }

    extension LocalAgentSettingType {
        var toAgentSetting: LocalAgent.SettingType {
            switch self {
            case .netshieldLevel: .netshieldLevel
            case .bouncing: .bouncing
            case .portForwarding: .portForwarding
            case .splitTcp: .splitTcp
            case .safeMode: .safeMode
            case .randomNat: .randomNat
            }
        }
    }

    extension LocalAgentSettings {
        var toVPNConnectionFeatures: VPNConnectionFeatures {
            .init(
                netshield: netshieldLevel?.toNetShieldType ?? .off,
                vpnAccelerator: splitTcp ?? false,
                bouncing: nil, // TODO: what should we do here?
                natType: randomNat.flatMap { NATType(flag: $0) } ?? .default,
                safeMode: softJail ?? false,
                portForwarding: portForwarding
            )
        }
    }
#endif
