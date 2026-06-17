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
import LocalAgent
import LocalAgentIPC
import protun

private func unknownDefault<T>(
    function: StaticString = #function,
    file: StaticString = #file,
    line: UInt = #line,
    value: T
) -> T {
    assertionFailure("Unknown value in \(function) (\(file):\(line))")
    return value
}

extension NetshieldLevel {
    var toNetShieldType: NetShieldType {
        switch self {
        case .none: .off
        case .malwareFilter: .level1
        case .adsAndMalwareFilter: .level2
        case .adultAndAdsAndMalwareFilter: .level3
        @unknown default:
            unknownDefault(value: .level1)
        }
    }
}

extension LocalAgentSettingType: @retroactive CustomStringConvertible {
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
        @unknown default:
            unknownDefault(value: "(unknown value)")
        }
    }
}

public extension LocalAgentSettingType {
    var toAgentSetting: LocalAgent.SettingType {
        switch self {
        case .netshieldLevel: .netshieldLevel
        case .bouncing: .bouncing
        case .portForwarding: .portForwarding
        case .splitTcp: .splitTcp
        case .safeMode: .safeMode
        case .randomNat: .randomNat
        @unknown default:
            unknownDefault(value: .netshieldLevel)
        }
    }
}

public extension LocalAgentSettings {
    var toVPNConnectionFeatures: VPNConnectionFeatures {
        .init(
            netshield: netshieldLevel?.toNetShieldType ?? .off,
            vpnAccelerator: splitTcp ?? false,
            natType: randomNat.flatMap { NATType(flag: $0) } ?? .default,
            portForwarding: portForwarding
        )
    }
}

extension VpnState: @retroactive CustomStringConvertible {
    public var description: String {
        switch connectionState {
        case let .disconnected(reason):
            ".disconnected(\(reason.stringForLog))"
        case let .connecting(peers, waitReasons):
            ".connecting(\(peers), \(waitReasons))"
        case let .connectingToLocalAgent(peers, waitReason):
            ".connectingToLocalAgent(\(peers), \(waitReason.stringForLog))"
        case let .connected(peers, agentInfo):
            ".connected(\(peers), \(agentInfo.stringForLog))"
        @unknown default:
            unknownDefault(value: "(unknown value)")
        }
    }
}

extension Event: @retroactive CustomStringConvertible {
    public var description: String {
        switch self {
        case let .connectionStats(_, rx, tx, idle, el, rtt):
            "connectionStats(rx:\(rx), tx:\(tx), idle:\(idle), eloss:\(el), rtt:\(rtt))"
        case let .packetCaptureStarted(info: info):
            String(describing: info)
        case let .packetCaptureStopped(reason: reason):
            String(describing: reason)
        case let .localAgentStats(rx, tx, malwb, adsb, trckb, adcob, ds):
            """
            localAgentStats(
                rx:\(rx, default: "0"),
                tx:\(tx, default: "0"),
                malwb:\(malwb, default: "0"),
                adsb:\(adsb, default: "0"),
                trckb:\(trckb, default: "0"),
                adcob:\(adcob, default: "0"),
                ds:\(ds, default: "0")
            )
            """
        case let .error(error: error):
            error.debugDescription
        @unknown default:
            unknownDefault(value: "(unknown value)")
        }
    }
}

extension ErrorEvent: @retroactive CustomDebugStringConvertible {
    public var debugDescription: String {
        switch self {
        case .apiSessionExpired:
            "apiSessionExpired"
        case let .localAgentSettingPolicyRefused(setting):
            "localAgentSettingPolicyRefused\(setting)"
        case .certificateRefreshFatalError:
            "certificateRefreshFatalError"
        @unknown default:
            unknownDefault(value: "(unknown value)")
        }
    }
}

extension ConnectionState: @retroactive CustomStringConvertible {
    public var description: String {
        switch self {
        case let .disconnected(error):
            "disconnected(\(String(describing: error)))"
        case let .connecting(peers, waitReasons):
            "connecting(\(peers), \(waitReasons)))"
        case let .connectingToLocalAgent(peer, waitReason):
            "connectingToLocalAgent(\(peer), \(String(describing: waitReason))))"
        case let .connected(peer, agentInfo):
            "connected(\(peer), \(String(describing: agentInfo))))"
        @unknown default:
            unknownDefault(value: "(unknown value)")
        }
    }
}

public extension WireGuardTransport {
    static func from(protocol: protun.`Protocol`) -> Self {
        switch `protocol` {
        case .wireguardUdp:
            .udp
        case .wireguardTcp:
            .tcp
        case .stealth:
            .tls
        @unknown default:
            unknownDefault(value: .udp)
        }
    }
}

extension CacheKey: @retroactive CustomStringConvertible {
    public var description: String {
        switch self {
        case .certificate:
            "certificate"
        case .privateKey:
            "privateKey"
        case .apiSession:
            "apiSession"
        @unknown default:
            unknownDefault(value: "(unknown value)")
        }
    }
}
