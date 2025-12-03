//
//  Created on 05/06/2024.
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

import CommonNetworking
import Dependencies
import Foundation
import NEHelper
import enum VPNShared.VPNAuthenticationStorageConfigKey

extension VPNAuthenticationStorageConfigKey: @retroactive DependencyKey {
    public static let liveValue: String = {
        let accessGroup = Bundle.main.infoDictionary!["AppIdentifierPrefix"] as! String
        return "\(accessGroup)prt.ProtonVPN"
    }()
}

extension CustomHostValidator: @retroactive DependencyKey {
    /// By default, `testValue` defined in `CommonNetworking` uses release host validation.
    /// Let's override it here when building for staging or debug.
    /// This cannot be done in `CommonNetworking` until SPM decides to allow more than just
    /// `debug` and `release` build configurations.
    public static let liveValue: CustomHostValidator = {
        #if DEBUG || STAGING
            return CustomHostValidator.debug
        #else
            return CustomHostValidator.release
        #endif
    }()
}

extension BuildConfigurationChecker: @retroactive DependencyKey {
    public static let liveValue: BuildConfigurationChecker = .init(buildConfiguration: {
        #if DEBUG
            return .debug
        #elseif STAGING
            return .staging
        #else
            return .release
        #endif
    })
}

extension VPNNetworkingKey: @retroactive DependencyKey {
    public static let liveValue: VPNNetworking = {
        #if TLS_PIN_DISABLE
            let pinAPIEndpoints = false
        #else
            let pinAPIEndpoints = true
        #endif

        let networking = CoreNetworking(
            delegate: Dependency(\.networkingDelegate).wrappedValue,
            appInfo: Dependency(\.appInfo).wrappedValue,
            pinApiEndpoints: pinAPIEndpoints
        )

        return CoreNetworkingWrapper(wrapped: networking)
    }()
}
