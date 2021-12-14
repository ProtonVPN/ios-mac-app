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

enum LocalAgentFeaturesKeys: String {
    case vpnAccelerator = "split-tcp"
    case netShield = "netshield-level"
    case jailed = "jail"
    case bouncing
}

extension LocalAgentFeatures {
    func hasKey(key: LocalAgentFeaturesKeys) -> Bool {
        return hasKey(key.rawValue)
    }

    func getInt(key: LocalAgentFeaturesKeys) -> Int? {
        guard hasKey(key: key) else {
            return nil
        }

        return getInt(key.rawValue)
    }
    
    func getBool(key: LocalAgentFeaturesKeys) -> Bool? {
        guard hasKey(key: key) else {
            return nil
        }

        return getBool(key.rawValue)
    }
    
    func getString(key: LocalAgentFeaturesKeys) -> String? {
        guard hasKey(key: key) else {
            return nil
        }

        return getString(key.rawValue)
    }

    func set(_ key: LocalAgentFeaturesKeys, value: Bool) {
        setBool(key.rawValue, value: value)
    }

    func set(_ key: LocalAgentFeaturesKeys, value: Int) {
        setInt(key.rawValue, value: value)
    }

    func set(_ key: LocalAgentFeaturesKeys, value: String) {
        setString(key.rawValue, value: value)
    }
}

extension LocalAgentFeatures {
    
    // MARK: Getters
    
    var vpnAccelerator: Bool? {
        return getBool(key: .vpnAccelerator)
    }

    var netshield: NetShieldType? {
        guard let value = getInt(key: .netShield) else {
            return nil
        }
        return NetShieldType(rawValue: value)
    }
    
    var bouncing: String? {
        return getString(key: .bouncing)
    }
    
    // MARK: -

    func with(netshield: NetShieldType) -> LocalAgentFeatures {
        set(.netShield, value: netshield.rawValue)
        return self
    }

    func with(jailed: Bool) -> LocalAgentFeatures {
        set(.jailed, value: jailed)
        return self
    }

    func with(vpnAccelerator: Bool) -> LocalAgentFeatures {
        set(.vpnAccelerator, value: vpnAccelerator)
        return self
    }

    func with(bouncing: String?) -> LocalAgentFeatures {
        if let bouncing = bouncing {
            set(.bouncing, value: bouncing)
        }
        return self
    }

    func with(configuration: LocalAgentConfiguration) -> LocalAgentFeatures {
        return self
            .with(netshield: configuration.features.netshield)
            .with(vpnAccelerator: configuration.features.vpnAccelerator)
            .with(bouncing: configuration.features.bouncing)
    }
}
