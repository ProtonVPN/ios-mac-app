//
//  Created on 11.12.2025 by John Biggs.
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
import Ergonomics
import Foundation
import ProtonCoreFeatureFlags

public extension FeatureFlagTypeProtocol {
    var shouldReportInHttpRequests: Bool {
        switch self {
        case let coreFlag as CoreFeatureFlagType:
            switch coreFlag {
            case .paymentsOmnichannelEnabled:
                true
            default:
                false
            }
        default:
            false
        }
    }

    /// This appears in all HTTP requests under the
    var requestName: String? {
        guard shouldReportInHttpRequests, enabled else {
            return nil
        }

        switch self {
        case is VPNFeatureFlagType:
            return "VPN.\(rawValue)"
        case is CoreFeatureFlagType:
            return "Core.\(rawValue)"
        default:
            assertionFailure("Unrecognized Feature Flag type \(Self.self)")
            return nil
        }
    }
}

public extension CheckedFeatureFlagsRepository {
    static var _enabledFeaturesRequestString: String = {
        let features: [any FeatureFlagTypeProtocol] = VPNFeatureFlagType.allCases + CoreFeatureFlagType.allCases
        return features.compactMap(\.requestName).joined(separator: ", ")
    }()

    static var enabledFeaturesRequestString: String {
        guard shared.hasFetchedFlags else { return "" }
        return _enabledFeaturesRequestString
    }
}
