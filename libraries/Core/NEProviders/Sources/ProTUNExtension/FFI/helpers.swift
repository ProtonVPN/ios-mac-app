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
import VPNCoreTypes

private func unknownDefault<T>(
    function: StaticString = #function,
    file: StaticString = #file,
    line: UInt = #line,
    value: T
) -> T {
    assertionFailure("Unknown value in \(function) (\(file):\(line))")
    return value
}

extension CurrentPeer {
    init?(from state: ConnectionState) {
        switch state {
        case let .connected(peer, agent):
            self = .init(
                peerID: peer.peerId,
                transport: .from(protocol: peer.protocol),
                serverExitV4: agent?.serverExitV4,
                userISP: agent?.userIspName,
                userIP: agent?.userIspIp
            )
        case let .connectingToLocalAgent(peer, _):
            self = .init(
                peerID: peer.peerId,
                transport: .from(protocol: peer.protocol),
                serverExitV4: nil,
                userISP: nil,
                userIP: nil
            )
        default:
            return nil
        }
    }
}

extension LocalAgentSettings {
    init(_ config: ProTUNConfiguration) {
        self.init(
            splitTcp: config.vpnAccelerator,
            netshieldLevel: config.netShieldLevel.flatMap { NetShieldType(rawValue: $0)?.toRustNetShieldLevel },
            softJail: config.softJail,
            portForwarding: config.portForwarding,
            randomNat: config.randomNat,
            circumventionRouting: config.circumventionRouting
        )
    }

    /// Overrides LocalAgent settings according to an update, leaving the rest unchanged. Used to build the
    /// settings forwarded to ProTUN from a partial update without persisting them to the configuration.
    mutating func apply(_ update: ConnectionUpdate) {
        if let netShield = update.netShield { netshieldLevel = netShield.toRustNetShieldLevel }
        if let vpnAccelerator = update.vpnAccelerator { splitTcp = vpnAccelerator }
        if let moderateNAT = update.moderateNAT { randomNat = moderateNAT.flag }
        if let portForwarding = update.portForwarding { self.portForwarding = portForwarding }
    }

    public var agentTunnelFeatures: AgentTunnelFeatures {
        AgentTunnelFeatures(
            netshield: netshieldLevel?.netShieldType ?? .off,
            vpnAccelerator: splitTcp ?? false,
            natType: NATType(flag: randomNat ?? false),
            portForwarding: portForwarding
        )
    }
}

public extension NetshieldLevel {
    var netShieldType: NetShieldType {
        switch self {
        case .none: .off
        case .malwareFilter: .level1
        case .adsAndMalwareFilter: .level2
        case .adultAndAdsAndMalwareFilter: .level3
        @unknown default: .off
        }
    }
}

public extension NetShieldType {
    var toRustNetShieldLevel: NetshieldLevel {
        switch self {
        case .off:
            .none
        case .level1:
            .malwareFilter
        case .level2:
            .adsAndMalwareFilter
        case .level3:
            .adultAndAdsAndMalwareFilter
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

public extension Domain.WireGuardTransport {
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
