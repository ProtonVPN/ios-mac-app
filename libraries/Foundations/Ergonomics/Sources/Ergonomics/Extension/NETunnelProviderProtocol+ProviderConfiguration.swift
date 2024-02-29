//
//  Created on 2022-09-30.
//
//  Copyright (c) 2022 Proton AG
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
import NetworkExtension

extension NETunnelProviderProtocol {

    fileprivate enum CustomKeys: String, CaseIterable {
        case connectedLogicalIdKey = "PVPNLogicalID"
        case connectedServerIpIdKey = "PVPNServerIpID"
        case uidKey = "UID"
        case wgProtocolKey = "wg-protocol"
        case featureFlagOverridesKey = "FeatureFlagOverrides"
        case forceConflictRefreshKey = "ShouldForceConflictRefresh"
    }

    private func ensureProviderConfig() {
        guard providerConfiguration == nil else { return }

        providerConfiguration = [:]
    }

    public var connectedLogicalId: String? {
        get {
            providerConfiguration?[.connectedLogicalIdKey] as? String ??
            providerConfiguration?["PVPNServerID"] as? String // old name for the key
        }
        set {
            ensureProviderConfig()
            providerConfiguration?[.connectedLogicalIdKey] = newValue
        }
    }

    public var connectedServerIpId: String? {
        get {
            providerConfiguration?[.connectedServerIpIdKey] as? String
        }
        set {
            ensureProviderConfig()
            providerConfiguration?[.connectedServerIpIdKey] = newValue
        }
    }

    public var appUid: uid_t? {
        get {
            providerConfiguration?[.uidKey] as? uid_t
        }
        set {
            ensureProviderConfig()
            providerConfiguration?[.uidKey] = newValue
        }
    }

    public var wgProtocol: String? {
        get {
            providerConfiguration?[.wgProtocolKey] as? String
        }
        set {
            ensureProviderConfig()
            providerConfiguration?[.wgProtocolKey] = newValue
        }
    }

    public var featureFlagOverrides: [String: [String: Bool]]? {
        get {
            providerConfiguration?[.featureFlagOverridesKey] as? [String: [String: Bool]]
        }
        set {
            ensureProviderConfig()
            providerConfiguration?[.featureFlagOverridesKey] = newValue
        }
    }

    public var unleashFeatureFlagShouldForceConflictRefresh: Bool {
        get {
            (providerConfiguration?[.forceConflictRefreshKey] as? Bool) ?? false
        }
        set {
            ensureProviderConfig()
            providerConfiguration?[.forceConflictRefreshKey] = newValue
        }
    }

    // MARK: - 

    public func backupCustomSettings() -> [String: Any] {
        ensureProviderConfig()

        var custom = [String: Any]()
        for key in CustomKeys.allCases {
            if providerConfiguration!.keys.contains(key.rawValue) {
                custom[key.rawValue] = providerConfiguration![key.rawValue]
            }
        }
        return custom
    }

    public func restoreCustomSettingsFrom(backup: [String: Any]) {
        ensureProviderConfig()

        for key in CustomKeys.allCases {
            if backup.keys.contains(key.rawValue) {
                providerConfiguration![key.rawValue] = backup[key.rawValue]
            }
        }
    }
}

fileprivate extension Dictionary<String, Any> {
    subscript(_ customKey: NETunnelProviderProtocol.CustomKeys) -> Any? {
        get {
            self[customKey.rawValue]
        }
        set {
            self[customKey.rawValue] = newValue
        }
    }
}
