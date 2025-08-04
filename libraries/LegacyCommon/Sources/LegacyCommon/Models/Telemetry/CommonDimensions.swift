//
//  Created on 25.09.23.
//
//  Copyright (c) 2023 Proton AG
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

import Dependencies
import Foundation

public enum CommonTelemetryDimensions {
    public enum VPNStatus: String, Encodable {
        case on
        case off
    }

    public enum UserTier: String, Encodable {
        case nonUser = "non-user"
        case free
        case paid
        case internalTier = "internal"
        case credentialLess = "credential-less"
    }

    static func userTier(vpnKeychain: any VpnKeychainProtocol) -> CommonTelemetryDimensions.UserTier {
        @Dependency(\.authKeychain) var authKeychain
        let userIsCredentialLess = authKeychain.fetch(forContext: .mainApp)?.isCredentialLess ?? false
        guard !userIsCredentialLess else {
            return .credentialLess
        }

        let cached: CachedVpnCredentials? = vpnKeychain.fetchCached()
        let tier = cached?.maxTier ?? .freeTier
        if tier == .internalTier {
            return .internalTier
        }
        return tier.isFreeTier ? .free : .paid
    }
}
