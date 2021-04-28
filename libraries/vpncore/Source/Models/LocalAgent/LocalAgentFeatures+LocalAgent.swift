//
//  LocalAgentFeatures.swift
//  vpncore - Created on 27.04.2021.
//
//  Copyright (c) 2019 Proton Technologies AG
//
//  This file is part of vpncore.
//
//  vpncore is free software: you can redistribute it and/or modify
//  it under the terms of the GNU General Public License as published by
//  the Free Software Foundation, either version 3 of the License, or
//  (at your option) any later version.
//
//  vpncore is distributed in the hope that it will be useful,
//  but WITHOUT ANY WARRANTY; without even the implied warranty of
//  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
//  GNU General Public License for more details.
//
//  You should have received a copy of the GNU General Public License
//  along with vpncore.  If not, see <https://www.gnu.org/licenses/>.
//

import Foundation
import WireguardSRP

extension LocalAgentFeatures {
    static func with(netshield: NetShieldType) -> LocalAgentFeatures? {
        let features = LocalAgentFeatures()
        switch netshield {
        case .off:
            break
        case .level1:
            features?.setInt("netshield-level", value: 1)
        case .level2:
            features?.setInt("netshield-level", value: 2)
        }
        return features
    }

    static func with(jailed: Bool) -> LocalAgentFeatures? {
        let features = LocalAgentFeatures()
        features?.setBool("jail", value: jailed)
        return features
    }
}
