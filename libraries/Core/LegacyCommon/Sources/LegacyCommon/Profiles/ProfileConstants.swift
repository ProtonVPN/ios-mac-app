//
//  ProfileConstants.swift
//  vpncore - Created on 26.06.19.
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

import Dependencies
import Domain
import Strings
import VPNAppCore

public enum ProfileConstants {
    public static let fastestId = "st_f"
    public static let randomId = "st_r"

    // WARNING: consuming client must contain "fastest" and "random" image assets
    //
    // NOTE: this is old behaviour. These two default profiles used to split by plan: 'random' was
    // free and 'fastest' was paid (that's why `randomProfile` hardcodes `accessTier` to 0 and
    // ignores its parameter). This barely matters now — profiles are a paid-only feature (see
    // `ProfileAuthorizer.canUseProfiles`), and free users get a free 'Fastest' connection instead of
    // 'random' (see `CountriesMainFeature`). These `accessTier` values can be cleaned up in Profiles 2.0
    public static func defaultProfiles(connectionProtocol: ConnectionProtocol) -> [Profile] {
        [
            fastestProfile(connectionProtocol: connectionProtocol, defaultProfileAccessTier: .paid),
            randomProfile(connectionProtocol: connectionProtocol, defaultProfileAccessTier: .paid),
        ]
    }

    /// Profile that connects to the fastest server based on the score field
    public static func fastestProfile(connectionProtocol: ConnectionProtocol, defaultProfileAccessTier: VpnTier) -> Profile {
        Profile(
            id: fastestId,
            accessTier: defaultProfileAccessTier,
            profileIcon: .bolt,
            profileType: .system,
            serverType: .unspecified,
            serverOffering: .fastest(nil),
            name: Localizable.fastest,
            connectionProtocol: connectionProtocol
        )
    }

    // Profile that selects country and server randomly
    public static func randomProfile(connectionProtocol: ConnectionProtocol, defaultProfileAccessTier _: VpnTier) -> Profile {
        Profile(
            id: randomId,
            accessTier: .free,
            profileIcon: .arrowsSwapRight,
            profileType: .system,
            serverType: .unspecified,
            serverOffering: .random(nil),
            name: Localizable.random,
            connectionProtocol: connectionProtocol
        )
    }
}
