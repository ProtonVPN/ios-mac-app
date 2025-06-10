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
import VPNShared
import LegacyCommon
import Persistence
import Ergonomics

// MARK: Live implementations of app dependencies

extension DatabaseConfigurationKey: @retroactive DependencyKey {
    public static let liveValue: DatabaseConfiguration = .live
}

extension ChallengeParametersProviderKey: @retroactive DependencyKey {
    public static let liveValue: ChallengeParametersProvider = .empty
}

extension DoHConfigurationKey: @retroactive DependencyKey {
    public static var liveValue: DoHVPN {
        @Dependency(\.propertiesManager) var propertiesManager

        let customHost = Bundle.dynamicDomain ?? propertiesManager.apiEndpoint
        let atlasSecret = Bundle.atlasSecret ?? propertiesManager.atlasSecret
        log.info("Custom host: \(optional: customHost), atlasSecret: \(optional: atlasSecret)")

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

extension CustomHostValidator: @retroactive DependencyKey {

    /// By default, `testValue` defined in `CommonNetworking` uses release host validation.
    /// Let's override it here when building for staging or debug.
    /// This cannot be done in `CommonNetworking` until SPM decides to allow more than just
    /// `debug` and `release` build configurations.
    public static let liveValue: CustomHostValidator = {
        #if DEBUG || STAGING
        log.info("Using debug custom host validator", category: .api)
        return CustomHostValidator.debug
        #else
        return CustomHostValidator.release
        #endif
    }()
}
