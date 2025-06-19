//
//  Created on 29/05/2025 by Max Kupetskyi.
//
//  Copyright (c) 2025 Proton AG
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

import Dependencies
import Foundation
import ProtonCorePaymentsV2

final class IapCachedStatus {
    @Dependency(\.storage) var storage
    @Dependency(\.defaultsProvider) var provider

    enum UserCachedStatusKeys: String, CaseIterable {
        case iapSupportStatus
        /// - Note: this value has been replaced by `iapSupportStatus`.
        case paymentsBackendStatusAcceptsIAP
    }

    var iapSupportStatus: IAPSupportStatusV2 {
        get {
            // First, try to get the newer `iapSupportStatus` default.
            if let status = try? storage.get(IAPSupportStatusV2.self, forKey: UserCachedStatusKeys.iapSupportStatus.rawValue) {
                return status
            }
            // If we can't find it, then fall back to the old value with a nil reason.
            guard provider.getDefaults().bool(forKey: UserCachedStatusKeys.paymentsBackendStatusAcceptsIAP.rawValue) else {
                return .disabled(localizedReason: nil)
            }
            return .enabled
        }
        set {
            try? storage.set(newValue, forKey: UserCachedStatusKeys.iapSupportStatus.rawValue)
        }
    }

    func clear() {
        for key in UserCachedStatusKeys.allCases {
            storage.removeObject(forKey: key.rawValue)
        }
    }
}
