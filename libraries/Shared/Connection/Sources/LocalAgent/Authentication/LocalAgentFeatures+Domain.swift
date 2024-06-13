//
//  Created on 04/06/2024.
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
import class GoLibs.LocalAgentFeatures
import Domain

enum LocalAgentFeaturesKeys: String {
    case vpnAccelerator = "split-tcp"
    case netShield = "netshield-level"
    case jailed = "jail"
    case natType = "randomized-nat"
    case bouncing
    case safeMode = "safe-mode"
}

extension LocalAgentFeatures {
    func hasKey(key: LocalAgentFeaturesKeys) -> Bool {
        return hasKey(key.rawValue)
    }

    func getInt(key: LocalAgentFeaturesKeys) -> Int? {
        guard hasKey(key: key) else {
            return nil
        }

        return Int(getInt(key.rawValue))
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
        setInt(key.rawValue, value: Int64(value))
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

    var natType: NATType? {
        guard let value = getBool(key: .natType) else {
            return nil
        }

        return NATType(flag: value)
    }

    var safeMode: Bool? {
        return getBool(key: .safeMode)
    }

    // MARK: - Setters

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

    func with(natType: NATType) -> LocalAgentFeatures {
        set(.natType, value: natType.flag)
        return self
    }

    func with(safeMode: Bool?) -> LocalAgentFeatures {
        if let safeMode = safeMode {
            set(.safeMode, value: safeMode)
        }
        return self
    }

    func with(configuration: ConnectionConfiguration) -> LocalAgentFeatures {
        return self
            .with(netshield: configuration.features.netshield)
            .with(vpnAccelerator: configuration.features.vpnAccelerator)
            .with(bouncing: configuration.features.bouncing)
            .with(natType: configuration.features.natType)
            .with(safeMode: configuration.features.safeMode)
    }
}

extension LocalAgentFeatures {
    var vpnFeatures: VPNConnectionFeatures? {
        guard let netshield = self.netshield, let vpnAccelerator = self.vpnAccelerator, let natType = self.natType, let safeMode = self.safeMode else {
            return nil
        }
        return VPNConnectionFeatures(netshield: netshield, vpnAccelerator: vpnAccelerator, bouncing: bouncing, natType: natType, safeMode: safeMode)
    }

}
