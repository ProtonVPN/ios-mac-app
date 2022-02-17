//
//  Created on 15.02.2022.
//
//  Copyright (c) 2022 Proton AG
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

public protocol SafeModePropertyProvider: PaidFeaturePropertyProvider {
    /// Current Safe Mdde
    var safeMode: Bool { get set }

    /// If the user can disable Safe Mode
    var isUserEligibleForSafeModeChange: Bool { get }
}

public protocol SafeModePropertyProviderFactory {
    func makeSafeModePropertyProvider() -> SafeModePropertyProvider
}

public class SafeModePropertyProviderImplementation: SafeModePropertyProvider {
    public let factory: Factory

    public required init(_ factory: Factory) {
        self.factory = factory
    }

    public var safeMode: Bool {
        get {
            // default to false when the feature is not enabled
            guard propertiesManager.featureFlags.safeMode else {
                return false
            }

            // true is the default value
            guard isUserEligibleForSafeModeChange else {
                return true
            }

            return propertiesManager.safeMode
        }
        set {
            guard isUserEligibleForSafeModeChange else {
                return
            }

            propertiesManager.safeMode = newValue
        }
    }

    public var isUserEligibleForSafeModeChange: Bool {
        return currentUserTier >= CoreAppConstants.VpnTiers.plus
    }
}
