//
//  Created on 19.01.2026 by John Biggs.
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
import Ergonomics
import Foundation

extension MigrationManager {
    /// Profiles created before the deprecation of OpenVPN can specify it as a custom conneciton protocol.
    /// This migration removes mentions of OpenVPN from the codebase (save for this migration logic), and updates any
    /// such protocols to defult to Smart protocol instead.
    func checkingProfiles() -> Self {
        checking(.platform(iOS: "7.1.0", macOS: "6.2.0", tvOS: nil)) { _ in
            @Dependency(\.defaultsProvider) var provider
            let defaults = provider.getDefaults()
            let profileEntries = defaults
                .dictionaryRepresentation()
                .filter { $0.key.hasPrefix("profiles_") }

            for entry in profileEntries {
                do {
                    let affectedProfileCount = try migrateProfiles(storageKey: entry.key, defaults: defaults)
                    log.info(
                        "Profiles migration finished",
                        category: .persistence,
                        metadata: ["key": "\(entry.key)", "affectedProfileCount": "\(affectedProfileCount)"]
                    )
                } catch {
                    log.error(
                        "Failed to migrate profile data",
                        category: .persistence,
                        metadata: ["key": "\(entry.key)", "error": "\(error)"]
                    )
                    defaults.set(nil, forKey: entry.key)
                }
            }
        }
    }

    /// Returns number of profiles that were affected by the migration (where the connection protocol was updated
    /// from OpenVPN to Smart.
    private func migrateProfiles(storageKey key: String, defaults: UserDefaults) throws -> Int {
        let decoder = JSONDecoder()
        let encoder = JSONEncoder()

        guard let data = defaults.data(forKey: key) else {
            log.error("Failed to load profile data", category: .persistence, metadata: ["key": "\(key)"])
            return 0
        }

        let oldProfiles = try decoder.decode([Profile.V1].self, from: data)
        let updatedProfiles = oldProfiles.map { Profile(migrating: $0) }
        try defaults.set(encoder.encode(updatedProfiles), forKey: key)

        let profilesAffectedByMigration = oldProfiles
            .filter(\.isAffectedByMigration)
            .count

        return profilesAffectedByMigration
    }
}

private extension VpnProtocol {
    enum V1: Decodable {
        case ike
        case openVpn // Previously, users have been able to select OpenVPN when creating a profile
        case wireGuard(WireGuardTransport)

        enum CodingKeys: String, CodingKey {
            case rawValue
            case transportProtocol
        }

        init(from decoder: Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)
            let rawValue = try container.decode(Int.self, forKey: .rawValue)

            switch rawValue {
            case 0:
                self = .ike
            case 1:
                self = .openVpn
            case 2:
                let transportProtocol = (try? container.decode(WireGuardTransport.self, forKey: .transportProtocol)) ?? .udp
                self = .wireGuard(transportProtocol)
            default:
                throw CodingError.unknownValue(rawValue)
            }
        }
    }
}

private extension ConnectionProtocol {
    enum V1: Decodable {
        case vpnProtocol(VpnProtocol.V1)
        case smartProtocol

        private enum CodingKeys: CodingKey {
            case smartProtocol
            case vpnProtocol
        }

        init(from decoder: Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)
            if let vpnProtocol = try container.decodeIfPresent(VpnProtocol.V1.self, forKey: .vpnProtocol) {
                self = .vpnProtocol(vpnProtocol)
            } else {
                self = .smartProtocol
            }
        }
    }

    init(migrating v1: V1) {
        switch v1 {
        case .vpnProtocol(.ike):
            self = .vpnProtocol(.ike)
        case let .vpnProtocol(.wireGuard(wgTransport)):
            self = .vpnProtocol(.wireGuard(wgTransport))
        case .vpnProtocol(.openVpn):
            // For the migration from V1 to V2, all OpenVPN must be migrated to smart protocol
            self = .smartProtocol
        case .smartProtocol:
            self = .smartProtocol
        }
    }
}

private extension Profile {
    struct V1: Decodable {
        public let id: String
        public let accessTier: Int
        public let profileIcon: ProfileIcon
        public let profileType: ProfileType
        public let serverType: ServerType
        public let serverOffering: ServerOffering
        public let name: String
        public let connectionProtocol: ConnectionProtocol.V1
        public let lastConnectedDate: Date?

        var isAffectedByMigration: Bool {
            if case .vpnProtocol(.openVpn) = connectionProtocol {
                return true
            }
            return false
        }
    }

    init(migrating v1: V1) {
        self.init(
            id: v1.id,
            accessTier: v1.accessTier,
            profileIcon: v1.profileIcon,
            profileType: v1.profileType,
            serverType: v1.serverType,
            serverOffering: v1.serverOffering,
            name: v1.name,
            connectionProtocol: .init(migrating: v1.connectionProtocol),
            lastConnectedDate: v1.lastConnectedDate
        )
    }
}
