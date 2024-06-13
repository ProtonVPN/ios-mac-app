//
//  Created on 03/06/2024.
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

import Foundation

import GoLibs

/// Data Transfer Object used for the features-statistics response received by Local Agent
struct FeatureStatisticsMessage: Decodable {
    let netShield: NetShieldStats

    enum CodingKeys: String, CodingKey {
        case netShield = "netshield-level"
    }

    struct NetShieldStats: Decodable {
        let malwareBlocked: Int?
        let adsBlocked: Int?
        let trackersBlocked: Int?
        let bytesSaved: Int // The only field guaranteed to be present

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
