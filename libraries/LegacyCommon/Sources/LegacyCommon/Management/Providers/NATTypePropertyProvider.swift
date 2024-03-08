//
//  Created on 07.02.2022.
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

import Domain
import VPNShared

public protocol NATTypePropertyProvider: FeaturePropertyProvider {
    /// Current NAT type
    var natType: NATType { get set }

    static var natTypeNotification: Notification.Name { get }
}

public protocol NATTypePropertyProviderFactory {
    func makeNATTypePropertyProvider() -> NATTypePropertyProvider
}

public class NATTypePropertyProviderImplementation: NATTypePropertyProvider {
    public static let natTypeNotification: Notification.Name = Notification.Name("NATTypeChanged")

    private let key = "NATType"

    @Dependency(\.featureAuthorizerProvider) private var featureAuthorizerProvider
    private var canUse: Bool {
        let authorizer = featureAuthorizerProvider.authorizer(for: NATFeature.self)
        return authorizer().isAllowed
    }

    public var natType: NATType {
        get {
            guard canUse else {
                return .default
            }

            @Dependency(\.defaultsProvider) var provider
            if let value = provider.getDefaults().userObject(forKey: key) as? Int, let natType = NATType(rawValue: value) {
                return natType
            }

            return .default
        }
        set {
            @Dependency(\.defaultsProvider) var provider
            provider.getDefaults().setUserValue(newValue.rawValue, forKey: key)
            executeOnUIThread {
                NotificationCenter.default.post(name: type(of: self).natTypeNotification, object: newValue, userInfo: nil)
            }
        }
    }

    public func adjustAfterPlanChange(from oldTier: Int, to tier: Int) {
        if tier.isFreeTier {
            natType = .default
        }
    }

    public init() {}
}

public struct NATFeature: PaidAppFeature { }
