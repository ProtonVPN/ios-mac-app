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
import Dependencies
import VPNShared

public protocol SafeModePropertyProvider: PaidFeaturePropertyProvider {
    /// Current Safe Mdde
    var safeMode: Bool? { get set }

    /// If the user can disable Safe Mode
    var isUserEligibleForSafeModeChange: Bool { get }

    var safeModeFeatureEnabled: Bool { get }

    static var safeModeNotification: Notification.Name { get }
}

public protocol SafeModePropertyProviderFactory {
    func makeSafeModePropertyProvider() -> SafeModePropertyProvider
}

public class SafeModePropertyProviderImplementation: SafeModePropertyProvider {
    public let factory: Factory

    public static let safeModeNotification: Notification.Name = Notification.Name("SafeModeChanged")

    private let key = "SafeMode"

    public required init(_ factory: Factory) {
        self.factory = factory
    }

    public var safeMode: Bool? {
        get {
            // default to nil when the feature is not enabled
            guard safeModeFeatureEnabled else {
                return nil
            }

            guard let username = username else {
                return nil
            }

            // true is the default value
            guard isUserEligibleForSafeModeChange else {
                return true
            }

            @Dependency(\.defaultsProvider) var provider
            guard let current = provider.getDefaults().value(forKey: key + username) as? Bool else {
                return true // true is the default value
            }

            return current
        }
        set {
            guard let username = username else {
                return
            }

            @Dependency(\.defaultsProvider) var provider
            provider.getDefaults().setValue(newValue, forKey: key + username)
            executeOnUIThread {
                NotificationCenter.default.post(name: type(of: self).safeModeNotification, object: newValue, userInfo: nil)
            }
        }
    }

    public var isUserEligibleForSafeModeChange: Bool {
        return currentUserTier >= CoreAppConstants.VpnTiers.basic
    }

    public var safeModeFeatureEnabled: Bool {
        return propertiesManager.featureFlags.safeMode
    }

    public func adjustAfterPlanChange(from oldTier: Int, to tier: Int) {
        if tier <= CoreAppConstants.VpnTiers.free {
            safeMode = true
        }
    }
}
