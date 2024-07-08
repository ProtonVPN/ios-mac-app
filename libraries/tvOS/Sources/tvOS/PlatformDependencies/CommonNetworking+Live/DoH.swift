//
//  Created on 02/05/2024.
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
import CommonNetworking

extension DoHConfigurationKey: DependencyKey {
    public static var liveValue = DoHVPN(alternativeRouting: false, customHost: nil)
}

extension DoHVPN {
    convenience init(alternativeRouting: Bool, customHost: String?) {

        let apiHost: String = ObfuscatedConstants.apiHost
        let humanVerificationV3Host = ObfuscatedConstants.humanVerificationV3Host
#if DEBUG
        let atlasSecret: String? = ObfuscatedConstants.atlasSecret
#else
        let atlasSecret: String? = nil
#endif

        self.init(
            apiHost: apiHost,
            verifyHost: humanVerificationV3Host,
            alternativeRouting: alternativeRouting,
            customHost: customHost,
            atlasSecret: atlasSecret,
            isConnected: false, // we can refactor this to be more TCA friendly in the future
            isAppStateNotificationConnected: { _ in false }
        )
    }
}
