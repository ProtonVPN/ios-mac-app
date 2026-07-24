//
//  Created on 19/12/2024.
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

public struct LocalTunnelFeatures: Equatable, Sendable, Codable {
    public let killSwitchMode: KillSwitchMode
    public let excludeLocalNetworks: Bool

    /// Whether any kill switch protection is enabled (Standard or Advanced).
    /// The IPC/tunnel layers only need this Bool "is KS on" signal; the Standard-vs-Advanced
    /// distinction is handled by the connection layer via ``killSwitchMode``.
    public var killSwitch: Bool {
        killSwitchMode.isProtected
    }

    #if !os(tvOS)
        public init(killSwitchMode: KillSwitchMode, excludeLocalNetworks: Bool) {
            self.killSwitchMode = killSwitchMode
            self.excludeLocalNetworks = excludeLocalNetworks
        }

        /// Convenience for callers that only distinguish on/off (previews, tests, legacy bridges).
        public init(killSwitch: Bool, excludeLocalNetworks: Bool) {
            self.init(killSwitchMode: killSwitch ? .standard : .off, excludeLocalNetworks: excludeLocalNetworks)
        }
    #else
        public static let tvFeatures: Self = .init()

        init() {
            self.killSwitchMode = .off
            self.excludeLocalNetworks = false
        }
    #endif

    // MARK: - Codable

    // Custom coding to stay backward-compatible with configurations persisted before the 3-state
    // migration, which encoded a `killSwitch` boolean instead of `killSwitchMode`.
    private enum CodingKeys: String, CodingKey {
        case killSwitchMode
        case killSwitch
        case excludeLocalNetworks
    }

    public init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.excludeLocalNetworks = try container.decodeIfPresent(Bool.self, forKey: .excludeLocalNetworks) ?? false
        if let mode = try container.decodeIfPresent(KillSwitchMode.self, forKey: .killSwitchMode) {
            self.killSwitchMode = mode
        } else if let legacyKillSwitch = try container.decodeIfPresent(Bool.self, forKey: .killSwitch) {
            self.killSwitchMode = legacyKillSwitch ? .standard : .off
        } else {
            self.killSwitchMode = .off
        }
    }

    public func encode(to encoder: any Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(killSwitchMode, forKey: .killSwitchMode)
        try container.encode(excludeLocalNetworks, forKey: .excludeLocalNetworks)
    }
}
