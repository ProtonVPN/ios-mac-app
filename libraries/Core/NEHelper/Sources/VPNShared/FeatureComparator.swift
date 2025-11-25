//
//  Created on 18/08/2025 by Chris Janusiewicz.
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

import Domain

public enum ConnectionFeatureComparator {
    struct AnyEquatableKeyPath {
        let keyPath: PartialKeyPath<VPNConnectionFeatures>
        let isSatisfied: (_ base: VPNConnectionFeatures, _ requirement: VPNConnectionFeatures) -> Bool

        init(_ keyPath: KeyPath<VPNConnectionFeatures, some Equatable>) {
            self.keyPath = keyPath
            self.isSatisfied = { base, required in
                base[keyPath: keyPath] == required[keyPath: keyPath]
            }
        }

        /// Comparison for optional features
        init(_ keyPath: KeyPath<VPNConnectionFeatures, (some Equatable)?>) {
            self.keyPath = keyPath
            self.isSatisfied = { base, required in
                guard let requiredFeature = required[keyPath: keyPath] else {
                    // If the feature is not specified, any value satisfies it
                    // If need be, we could make this throwing and always
                    // require concrete values here.
                    return true
                }
                guard let baseFeature = base[keyPath: keyPath] else {
                    // We require the feature to be set to a concrete value,
                    // but it's not specified by the certificate
                    // We could argue that if the feature is required to be
                    // off, then a nil value here satisfies the requirement
                    return false
                }
                return baseFeature == requiredFeature
            }
        }
    }

    public enum Feature: Equatable, CustomStringConvertible, CaseIterable {
        case netshield
        case vpnAccelerator
        case bouncing
        case natType
        case safeMode
        case portForwarding

        var erasedKeyPath: AnyEquatableKeyPath {
            switch self {
            case .netshield:
                AnyEquatableKeyPath(\.netshield)
            case .vpnAccelerator:
                AnyEquatableKeyPath(\.vpnAccelerator)
            case .bouncing:
                AnyEquatableKeyPath(\.bouncing)
            case .natType:
                AnyEquatableKeyPath(\.natType)
            case .safeMode:
                AnyEquatableKeyPath(\.safeMode)
            case .portForwarding:
                AnyEquatableKeyPath(\.portForwarding)
            }
        }

        public var description: String {
            switch self {
            case .netshield:
                "netshield"
            case .vpnAccelerator:
                "vpnAccelerator"
            case .bouncing:
                "bouncing"
            case .natType:
                "natType"
            case .safeMode:
                "safeMode"
            case .portForwarding:
                "portForwarding"
            }
        }
    }

    public enum Failure: Error, Equatable {
        case unsatisfiedFeatures([Feature])
    }

    public static func storedFeatures(
        _ features: VPNConnectionFeatures,
        satisfy requiredFeatures: VPNConnectionFeatures
    ) -> Result<Void, Failure> {
        let unsatisfiedFeatures = Feature.allCases
            .filter { !$0.erasedKeyPath.isSatisfied(features, requiredFeatures) }

        guard unsatisfiedFeatures.isEmpty else {
            return .failure(.unsatisfiedFeatures(unsatisfiedFeatures))
        }
        return .success(())
    }
}
