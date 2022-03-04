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

    private let storage: Storage
    private let key = "SafeMode"

    public required init(_ factory: Factory, storage: Storage, userInfoProvider: UserInfoProvider) {
        self.factory = factory
        self.storage = storage
    }

    public var safeMode: Bool? {
        get {
            // default to nil when the feature is not enabled
            guard safeModeFeatureEnabled else {
                return nil
            }

            // true is the default value
            guard isUserEligibleForSafeModeChange else {
                return true
            }

            guard let current = storage.defaults.value(forKey: key) as? Bool else {
                return true // true is the default value
            }

            return current
        }
        set {
            storage.setValue(newValue, forKey: key)
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

    public func resetForIneligibleUser() {
        safeMode = true
    }
}
