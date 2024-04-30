//
//  Created on 03/03/2024.
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

import Dependencies

import ProtonCoreFoundations

import CommonNetworking
import LegacyCommon
import Persistence

// MARK: Live implementations of app dependencies

extension DatabaseConfigurationKey: DependencyKey {
    public static let liveValue: DatabaseConfiguration = .live
}

extension ChallengeParametersProviderKey: DependencyKey {
    public static let liveValue: ChallengeParametersProvider = .empty
}

extension DoHConfigurationKey: DependencyKey {
    public static var liveValue: DoHVPN {
        @Dependency(\.propertiesManager) var propertiesManager

#if DEBUG || STAGING
        let customHost = propertiesManager.apiEndpoint
#else
        let customHost: String? = nil
#endif

        let doh = DoHVPN(
            alternativeRouting: propertiesManager.alternativeRouting,
            customHost: customHost
        )

        propertiesManager.onAlternativeRoutingChange = { alternativeRouting in
            doh.alternativeRouting = alternativeRouting
        }
        return doh
    }
}

extension DoHVPN {
    convenience init(alternativeRouting: Bool, customHost: String?) {
#if !RELEASE
        let atlasSecret: String? = ObfuscatedConstants.atlasSecret
#else
        let atlasSecret: String? = nil
#endif

        self.init(
            apiHost: ObfuscatedConstants.apiHost,
            verifyHost: ObfuscatedConstants.humanVerificationV3Host,
            alternativeRouting: alternativeRouting,
            customHost: customHost,
            atlasSecret: atlasSecret,
            isConnected: false, // Will get updated once AppStateManager is initialized
            isAppStateNotificationConnected: DoHVPN.isAppStateChangeNotificationInConnectedState
        )
    }
}
