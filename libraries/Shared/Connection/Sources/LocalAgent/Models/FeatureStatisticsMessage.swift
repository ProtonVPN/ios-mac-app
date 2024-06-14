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
struct FeatureStatisticsMessage {
    let netShield: NetShieldStats

    struct NetShieldStats: Decodable {
        let malwareBlocked: Int?
        let adsBlocked: Int?
        let trackersBlocked: Int?
        let bytesSaved: Int // The only field guaranteed to be present
    }
}

extension FeatureStatisticsMessage {

    init(localAgentStatsDictionary: LocalAgentStringToValueMap) throws {
        let data = try localAgentStatsDictionary.marshalJSON()

        let statsKey = localAgentConsts.statsNetshieldLevelKey
        guard let netShieldDictionary = localAgentStatsDictionary.getMap(statsKey) else {
            throw LocalAgentMessageDecodingError.missingRequiredValue(key: statsKey)
        }

        self.init(netShield: .init(
            malwareBlocked: netShieldDictionary.int(forKey: localAgentConsts.statsMalwareKey),
            adsBlocked: netShieldDictionary.int(forKey: localAgentConsts.statsAdsKey),
            trackersBlocked: netShieldDictionary.int(forKey: localAgentConsts.statsTrackerKey),
            bytesSaved: try netShieldDictionary.intOrThrow(forKey: localAgentConsts.statsSavedBytesKey)
        ))
    }
}
