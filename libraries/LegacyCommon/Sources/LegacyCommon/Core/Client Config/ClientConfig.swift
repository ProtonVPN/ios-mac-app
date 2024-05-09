//
//  ClientConfig.swift
//  vpncore - Created on 2020-09-08.
//
//  Copyright (c) 2019 Proton Technologies AG
//
//  This file is part of LegacyCommon.
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
//  along with LegacyCommon.  If not, see <https://www.gnu.org/licenses/>.
//

import Foundation
import VPNShared

public struct ClientConfig {
    public let featureFlags: FeatureFlags
    public let serverRefreshInterval: Int
    public let wireGuardConfig: WireguardConfig
    public let smartProtocolConfig: SmartProtocolConfig
    public let ratingSettings: RatingSettings
    public let serverChangeConfig: ServerChangeConfig

    public init(
        featureFlags: FeatureFlags,
        serverRefreshInterval: Int,
        wireGuardConfig: WireguardConfig,
        smartProtocolConfig: SmartProtocolConfig,
        ratingSettings: RatingSettings,
        serverChangeConfig: ServerChangeConfig
    ) {
        self.featureFlags = featureFlags
        self.serverRefreshInterval = serverRefreshInterval
        self.wireGuardConfig = wireGuardConfig
        self.smartProtocolConfig = smartProtocolConfig
        self.ratingSettings = ratingSettings
        self.serverChangeConfig = serverChangeConfig
    }

    public init() {
        self.init(
            featureFlags: FeatureFlags(),
            serverRefreshInterval: CoreAppConstants.Maintenance.defaultMaintenanceCheckTime,
            wireGuardConfig: WireguardConfig(),
            smartProtocolConfig: SmartProtocolConfig(),
            ratingSettings: RatingSettings(),
            serverChangeConfig: ServerChangeConfig()
        )
    }
}

/// Encapsulates the three server change config properties.
///
/// - Note: The response for `vpn/v2/clientconfig` does not encapsulate these properties, so it should be decoded directly
/// without using a container.
public struct ServerChangeConfig: Codable, DefaultableProperty {
    let changeServerAttemptLimit: Int
    let changeServerShortDelayInSeconds: Int
    let changeServerLongDelayInSeconds: Int

    public init(
        changeServerAttemptLimit: Int,
        changeServerShortDelayInSeconds: Int,
        changeServerLongDelayInSeconds: Int
    ) {
        self.changeServerAttemptLimit = changeServerAttemptLimit
        self.changeServerShortDelayInSeconds = changeServerShortDelayInSeconds
        self.changeServerLongDelayInSeconds = changeServerLongDelayInSeconds
    }

    public init() {
        self.init(
            changeServerAttemptLimit: 4,
            changeServerShortDelayInSeconds: 90,
            changeServerLongDelayInSeconds: 1200
        )
    }
}
