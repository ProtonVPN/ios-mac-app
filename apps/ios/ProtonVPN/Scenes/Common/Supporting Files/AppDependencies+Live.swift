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

import ProtonCoreFeatureFlags

import LegacyCommon
import VPNAppCore
import VPNShared
import Persistence
import Ergonomics

// MARK: Live implementations of app dependencies

extension DatabaseConfigurationKey: DependencyKey {
    public static let liveValue: DatabaseConfiguration = .live
}

import CommonNetworking
import ProtonCoreChallenge
import ProtonCoreFoundations

extension ChallengeParametersProviderKey: DependencyKey {
    public static let liveValue: ChallengeParametersProvider = .forAPIService(clientApp: .vpn, challenge: PMChallenge())
}

extension DoHConfigurationKey: DependencyKey {
    public static var liveValue: DoHVPN {
        @Dependency(\.propertiesManager) var propertiesManager

        #if RELEASE
        let customHost: String? = nil
        let atlasSecret: String? = nil
        log.info("Custom host is disabled (release configuration)")
        #else
        let customHost = Bundle.dynamicDomain ?? propertiesManager.apiEndpoint
        let atlasSecret = Bundle.atlasSecret ?? propertiesManager.atlasSecret
        log.info("Custom host: \(optional: customHost), atlasSecret: \(optional: atlasSecret)")
        #endif

        let doh = DoHVPN(
            alternativeRouting: propertiesManager.alternativeRouting,
            customHost: customHost,
            atlasSecret: atlasSecret
        )

        propertiesManager.onAlternativeRoutingChange = { alternativeRouting in
            doh.alternativeRouting = alternativeRouting
        }

        return doh
    }
}

extension DoHVPN {
    convenience init(alternativeRouting: Bool, customHost: String?, atlasSecret: String?) {
        self.init(
            apiHost: ObfuscatedConstants.apiHost,
            verifyHost: ObfuscatedConstants.humanVerificationV3Host,
            alternativeRouting: alternativeRouting,
            customHost: customHost,
            atlasSecret: atlasSecret,
            // Will get updated once AppStateManager is initialized
            isConnected: false,
            isAppStateNotificationConnected: DoHVPN.isAppStateChangeNotificationInConnectedState
        )
    }
}
