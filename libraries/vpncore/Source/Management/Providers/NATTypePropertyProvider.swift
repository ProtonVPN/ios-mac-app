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

public protocol NATTypePropertyProvider: PaidFeaturePropertyProvider {
    /// Current NAT type
    var natType: NATType { get set }

    /// If the user can change NAT Type
    var isUserEligibleForNATTypeChange: Bool { get }

    static var natTypeNotification: Notification.Name { get }
}

public protocol NATTypePropertyProviderFactory {
    func makeNATTypePropertyProvider() -> NATTypePropertyProvider
}

public class NATTypePropertyProviderImplementation: NATTypePropertyProvider {
    public let factory: Factory

    public static let natTypeNotification: Notification.Name = Notification.Name("NATTypeChanged")

    private let storage: Storage
    private let key = "NATType"
    private let userInfoProvider: UserInfoProvider

    public required init(_ factory: Factory, storage: Storage, userInfoProvider: UserInfoProvider) {
        self.factory = factory
        self.storage = storage
        self.userInfoProvider = userInfoProvider
    }

    public var natType: NATType {
        get {
            guard isUserEligibleForNATTypeChange else {
                return .default
            }

            guard let username = type(of: userInfoProvider).username else {
                return .default
            }

            if let value = storage.defaults.object(forKey: key + username) as? Int, let natType = NATType(rawValue: value) {
                return natType
            }

            return .default
        }
        set {
            guard let username = type(of: userInfoProvider).username else {
                return
            }

            storage.setValue(newValue.rawValue, forKey: key + username)
            executeOnUIThread {
                NotificationCenter.default.post(name: type(of: self).natTypeNotification, object: newValue, userInfo: nil)
            }
        }
    }

    public var isUserEligibleForNATTypeChange: Bool {
        return currentUserTier >= CoreAppConstants.VpnTiers.basic
    }

    public func resetForIneligibleUser() {
        natType = .default
    }
}
