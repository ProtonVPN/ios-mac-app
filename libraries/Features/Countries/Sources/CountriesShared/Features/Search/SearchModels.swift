//
//  Created on 19/02/2026 by Max Kupetskyi.
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

import Foundation
import Strings

public enum SearchMode: Equatable {
    case standard(isFreeTier: Bool)
    case secureCore
}

public enum ServerTier: Int, Equatable, Sendable {
    case free = 0
    case plus = 2

    var title: String {
        switch self {
        case .plus:
            Localizable.plusServers
        case .free:
            Localizable.freeServers
        }
    }

    public static func sorted(isFreeTier: Bool) -> [ServerTier] {
        isFreeTier ? [.free, .plus] : [.plus, .free]
    }
}

public struct SearchCountryIndex: Equatable, Identifiable, Sendable {
    public let id: String
    public let countryCode: String
    public let name: String
}

public struct SearchCityIndex: Equatable, Identifiable, Sendable {
    public let id: String
    public let cityName: String
    public let translatedCityName: String?
    public let countryName: String
    public let countryCode: String
}

public struct SearchServerIndex: Equatable, Identifiable, Sendable {
    public let id: String
    public let serverName: String
    public let cityName: String
    public let translatedCityName: String?
    public let countryName: String
    public let exitCountryCode: String
    public let entryCountryCode: String?
    public let tier: ServerTier
    public let load: Int
    public let isP2PAvailable: Bool
    public let isTorAvailable: Bool
    public let isSmartAvailable: Bool
    public let isStreamingAvailable: Bool
    public let isUsersTierTooLow: Bool
    public let underMaintenance: Bool
}
