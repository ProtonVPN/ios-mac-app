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

public enum LocalAgent {
    /// Identifies a single Local Agent setting reported back by the Rust LA layer — typically
    /// inside a `policyRefused` error so the UI knows which setting the server rejected.
    ///
    /// Mirrors the Rust FFI `LocalAgentSettingType` 1:1 (see `helpers.swift::toAgentSetting`).
    /// This is intentionally *not* the same shape as ``IPCLASettingsPayload`` (which represents
    /// the effective settings snapshot) nor ``ConnectionFeatureChange/AgentFeature`` (the
    /// user-writable subset). Each enum serves a different role.
    public enum SettingType: Codable {
        case netshieldLevel
        case bouncing
        case portForwarding
        case splitTcp
        case safeMode
        case randomNat
    }

    @DebugDescription
    public enum Event: Codable {
        case stats(Stats)
        case connectionStats(ConnectionStats)
        case features(VPNConnectionFeatures)
        case error(Error)
    }

    @DebugDescription
    public enum Request: Codable {
        case getFeatures
        case setFeatures(Set<ConnectionFeatureChange.AgentFeature>)
    }
}

extension LocalAgent.Event: Sendable {}

package extension NetShieldType {
    var shouldObserveNetShieldStats: Bool {
        switch self {
        case .off, .level1:
            false
        case .level2, .level3:
            true
        }
    }
}

extension LocalAgent.Event: CustomDebugStringConvertible {
    public var debugDescription: String {
        switch self {
        case let .stats(localAgentStats):
            "stats(\(localAgentStats))"
        case let .connectionStats(connectionStats):
            "connectionStats(\(connectionStats))"
        case let .features(features):
            "features(\(features))"
        case let .error(localAgentError):
            "error(\(localAgentError))"
        }
    }
}

extension LocalAgent.Request: CustomStringConvertible {
    public var description: String {
        switch self {
        case .getFeatures:
            "getFeatures"
        case .setFeatures:
            "setFeatures"
        }
    }
}
