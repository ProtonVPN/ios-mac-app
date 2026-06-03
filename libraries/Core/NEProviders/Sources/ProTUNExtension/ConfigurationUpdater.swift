//
//  Created on 01/06/2026.
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
import Domain
import NetworkExtension
import VPNCoreCommon

enum ConfigurationUpdater {
    static var proTUNManager: NETunnelProviderManager {
        get async throws(Failure) {
            let manager: NETunnelProviderManager?
            do {
                let managers = try await NETunnelProviderManager.loadAllFromPreferences()
                manager = managers.first {
                    ($0.protocolConfiguration as? NETunnelProviderProtocol)?
                        .providerBundleIdentifier == "ch.protonmail.vpn.ProTUN-Extension-Mobile"
                }
            } catch {
                throw .missingManager
            }
            guard let manager else {
                throw .missingManager
            }
            return manager
        }
    }

    // TODO: ProTUN: Test this behaviour in RELEASE mode
    static func updateConfiguration(
        changes: Set<ConnectionChange>,
        adapter: ProTUNAdapter
    ) async throws(Failure) {
        let manager = try await proTUNManager
        guard let config = manager.protocolConfiguration as? NETunnelProviderProtocol else {
            throw .badConfiguration
        }

        for change in changes {
            switch change {
            case let .location(spec, peers):
                // This also allows transport restrictions - e.g. passing only UDP peers/ports to restrict to UDP
                guard let connection = adapter.connection else {
                    throw .location(.noConnection)
                }
                do {
                    let peers: [PeerInfo] = try peers.map { try .init(from: $0) }
                    let specData = try JSONEncoder().encode(spec)
                    config.setProviderConfiguration(value: specData, forKey: "connectionSpec")
                    connection.updatePeers(peers: peers)
                } catch {
                    throw .location(.badPeers)
                }

            case .feature(.agent):
                // Features applied through local agent are not persisted via the configuration.
                continue

            case let .feature(.tunnel(.allowLAN(allowed))):
                config.excludeLocalNetworks = !allowed

            case let .feature(.tunnel(.killSwitch(enabled))):
                config.includeAllNetworks = enabled

            case .feature(.tunnel(.connectionProtocol)):
                // TODO: ProTUN: update peers accordingly to what ports they specify, or remove in favour of .location
                throw .unhandledChange(change)

            case .feature(.tunnel(.customDNS)):
                // TODO: ProTUN: Custom DNS support
                throw .unhandledChange(change)

            case let .feature(.tunnel(.onDemand(enabled))):
                manager.isOnDemandEnabled = enabled
            }
        }

        do {
            try await proTUNManager.saveToPreferences()
        } catch {
            throw .saveFailure(error)
        }
    }

    enum Failure: Error {
        case badConfiguration
        case location(Location)
        case missingManager
        case saveFailure(Error)
        case unhandledChange(ConnectionChange)

        enum Location: Error {
            case badPeers
            case noConnection
        }
    }
}
