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

import Combine
import CommonNetworking
import Connection
import Dependencies
import Ergonomics
import Foundation
import LegacyCommon
import Persistence
import PMLogger
import ProtonCoreFoundations
import Sharing
import VPNAppCore

// MARK: Live implementations of app dependencies

extension ChallengeParametersProviderKey: @retroactive DependencyKey {
    public static let liveValue: ChallengeParametersProvider = .empty
}

extension DoHConfigurationKey: @retroactive DependencyKey {
    public static var liveValue: DoHVPN {
        @SharedReader(.apiEndpoint) var apiEndpoint
        @SharedReader(.atlasSecret) var atlasSecretSetting
        var cancellables: Set<AnyCancellable> = []

        let customHost = Bundle.dynamicDomain ?? apiEndpoint
        let atlasSecret = Bundle.atlasSecret ?? atlasSecretSetting
        log.info("Custom host: \(optional: customHost), atlasSecret: \(optional: atlasSecret)")

        @SharedReader(.alternativeRouting) var alternativeRouting

        let doh = DoHVPN(
            alternativeRouting: alternativeRouting,
            customHost: customHost,
            atlasSecret: atlasSecret
        )

        $alternativeRouting.publisher.sink { alternativeRouting in
            doh.alternativeRouting = alternativeRouting
        }.store(in: &cancellables)

        return doh
    }
}

extension DoHVPN {
    convenience init(alternativeRouting: Bool, customHost: String?, atlasSecret: String?) {
        @SharedReader(.connectionState) var connectionState
        self.init(
            apiHost: ObfuscatedConstants.apiHost,
            verifyHost: ObfuscatedConstants.humanVerificationV3Host,
            alternativeRouting: alternativeRouting,
            customHost: customHost,
            atlasSecret: atlasSecret,
            isConnected: connectionState.is(\.connected),
            connectionStatusStream: { [$connectionState] in
                $connectionState
                    .publisher
                    .map { $0.is(\.connected) }
                    .removeDuplicates()
                    .values
            }
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

extension VPNNetworkingKey: @retroactive DependencyKey {
    public static let liveValue: VPNNetworking = {
        #if TLS_PIN_DISABLE
            let pinAPIEndpoints = false
        #else
            let pinAPIEndpoints = true
        #endif

        let networking = CoreNetworking(pinApiEndpoints: pinAPIEndpoints)

        return CoreNetworkingWrapper(wrapped: networking)
    }()
}

extension AppInfoKey: @retroactive DependencyKey {
    public static var liveValue: AppInfo = {
        @SharedReader(.earlyAccess) var earlyAccess

        return .live(context: .mainApp, beta: earlyAccess)
    }()
}
