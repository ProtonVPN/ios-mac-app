//
//  Created on 24/03/2023.
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
//  along with ProtonVPN.  If not, see <https://www.gnu.org/licenses/>.

import Foundation
import GoLibs
import Network

struct ConnectionDetailsMessage {
    let exitIp: IPAddress?
    let deviceIp: IPAddress?
    let deviceCountry: String?
}

extension ConnectionDetailsMessage {
    /// `LocalAgentConnectionDetails` is received with the `StatusUpdate` LocalAgent message.
    ///
    /// None of the fields of `LocalAgentConnectionDetails` are optional, so an empty string indicates a missing field.
    /// This wrapper struct makes sure that the IPs are valid before doing anything with them.
    init(details: LocalAgentConnectionDetails) {
        if !details.serverIpv4.isEmpty, let ipv4 = IPv4Address(details.serverIpv4) {
            self.exitIp = ipv4
        } else if !details.serverIpv6.isEmpty, let ipv6 = IPv6Address(details.serverIpv6) {
            self.exitIp = ipv6
        } else {
            self.exitIp = nil
        }

        if !details.deviceCountry.isEmpty {
            self.deviceCountry = details.deviceCountry
        } else {
            self.deviceCountry = nil
        }

        if !details.deviceIp.isEmpty {
            if let ipv4 = IPv4Address(details.deviceIp) {
                self.deviceIp = ipv4
            } else if let ipv6 = IPv6Address(details.deviceIp) {
                self.deviceIp = ipv6
            } else {
                self.deviceIp = nil
            }
        } else {
            self.deviceIp = nil
        }
    }
}

/// Data Transfer Object used for the features-statistics response received by Local Agent
struct FeatureStatisticsMessage: Decodable {
    let netShield: NetShieldStats

    enum CodingKeys: String, CodingKey {
        case netShield = "netshield-level"
    }

    /// Only dataSaved
    struct NetShieldStats: Decodable {
        let malwareBlocked: Int?
        let adsBlocked: Int?
        let trackersBlocked: Int?
        let bytesSaved: Int64 // The only field guaranteed to be present

        // Unable to use non-literals like LocalAgentConsts().statsAdsKey as enum rawvalues.
        // We could maybe implement CodingKey using a struct, or not use Codable for this at all
        enum CodingKeys: String, CodingKey {
            case malwareBlocked = "DNSBL/1b"
            case adsBlocked = "DNSBL/2a"
            case trackersBlocked = "DNSBL/2b"
            case bytesSaved = "savedBytes"
        }
    }
}

extension FeatureStatisticsMessage {
    init(localAgentStatsDictionary: LocalAgentStringToValueMap) throws {
        let data = try localAgentStatsDictionary.marshalJSON()
        self = try JSONDecoder().decode(FeatureStatisticsMessage.self, from: data)
    }
}
