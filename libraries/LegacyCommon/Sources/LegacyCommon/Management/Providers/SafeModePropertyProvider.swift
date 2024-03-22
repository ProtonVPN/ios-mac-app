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
import Ergonomics
import VPNShared

public protocol SafeModePropertyProvider: FeaturePropertyProvider {
    /// Current Safe Mdde
    var safeMode: Bool? { get set }

    static var safeModeNotification: Notification.Name { get }
}

public protocol SafeModePropertyProviderFactory {
    func makeSafeModePropertyProvider() -> SafeModePropertyProvider
}

public class SafeModePropertyProviderImplementation: SafeModePropertyProvider {
    public static let safeModeNotification: Notification.Name = Notification.Name("SafeModeChanged")

    private let key = "SafeMode"

    @Dependency(\.featureAuthorizerProvider) private var featureAuthorizerProvider
    private var canUse: Bool {
        let authorizer = featureAuthorizerProvider.authorizer(for: SafeModeFeature.self)
        return authorizer().isAllowed
    }

    public var safeMode: Bool? {
        get {
            guard canUse else { return nil }

            @Dependency(\.defaultsProvider) var provider
            guard let current = provider.getDefaults().userValue(forKey: key) as? Bool else {
                return true // true is the default value
            }

            return current
        }
        set {
            @Dependency(\.defaultsProvider) var provider
            provider.getDefaults().setUserValue(newValue, forKey: key)
            executeOnUIThread {
                NotificationCenter.default.post(name: type(of: self).safeModeNotification, object: newValue, userInfo: nil)
            }
        }
    }

    public func adjustAfterPlanChange(from oldTier: Int, to tier: Int) {
        guard tier.isPaidTier else {
            safeMode = false
            return
        }

        safeMode = true
    }

    public init() {}
}

public struct SafeModeFeature: PaidAppFeature {
    public static let featureFlag: KeyPath<FeatureFlags, Bool>? = \.safeMode
}
