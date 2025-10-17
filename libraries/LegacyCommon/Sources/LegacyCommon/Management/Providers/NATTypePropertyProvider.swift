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
import Ergonomics
import VPNShared

public struct NATTypePropertyProvider {
    /// Get the current NAT type
    public var getNATType: () -> NATType

    /// Set the NAT type
    public var setNATType: (NATType) -> Void

    /// Adjust settings after plan change
    public var adjustAfterPlanChangeClosure: (_ from: Int, _ to: Int) -> Void

    public init(
        getNATType: @escaping () -> NATType,
        setNATType: @escaping (NATType) -> Void,
        adjustAfterPlanChange: @escaping (Int, Int) -> Void
    ) {
        self.getNATType = getNATType
        self.setNATType = setNATType
        self.adjustAfterPlanChangeClosure = adjustAfterPlanChange
    }
}

extension NATTypePropertyProvider: FeaturePropertyProvider {
    public func adjustAfterPlanChange(from oldTier: Int, to tier: Int) {
        adjustAfterPlanChangeClosure(oldTier, tier)
    }
}

public struct NATFeature: PaidAppFeature {}

// MARK: - Dependency Key

extension NATTypePropertyProvider: DependencyKey {
    private static let key = "NATType"

    public static let liveValue: Self = {
        @Dependency(\.featureAuthorizerProvider) var featureAuthorizerProvider
        @Dependency(\.defaultsProvider) var defaultsProvider

        let canUse: () -> Bool = {
            let authorizer = featureAuthorizerProvider.authorizer(for: NATFeature.self)
            return authorizer().isAllowed
        }

        return Self(
            getNATType: {
                guard canUse() else {
                    return .default
                }

                if let value = defaultsProvider.getDefaults().userObject(forKey: key) as? Int,
                   let natType = NATType(rawValue: value) {
                    return natType
                }

                return .default
            },
            setNATType: { newValue in
                defaultsProvider.getDefaults().setUserValue(newValue.rawValue, forKey: key)
                executeOnUIThread {
                    AppEvent.natType.post(newValue)
                }
            },
            adjustAfterPlanChange: { _, tier in
                if tier.isFreeTier {
                    defaultsProvider.getDefaults().setUserValue(NATType.default.rawValue, forKey: key)
                    executeOnUIThread {
                        AppEvent.natType.post(NATType.default)
                    }
                }
            }
        )
    }()

    #if DEBUG
        public static let testValue: Self = .init(
            getNATType: { .default },
            setNATType: { _ in },
            adjustAfterPlanChange: { _, _ in }
        )
    #endif
}

public extension DependencyValues {
    var natTypePropertyProvider: NATTypePropertyProvider {
        get { self[NATTypePropertyProvider.self] }
        set { self[NATTypePropertyProvider.self] = newValue }
    }
}
