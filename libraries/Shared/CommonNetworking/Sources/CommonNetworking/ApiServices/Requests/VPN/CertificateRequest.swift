//
//  CertificateRequest.swift
//  vpncore - Created on 06.04.2021.
//
//  Copyright (c) 2019 Proton Technologies AG
//
//  This file is part of LegacyCommon.
//
//  vpncore is free software: you can redistribute it and/or modify
//  it under the terms of the GNU General Public License as published by
//  the Free Software Foundation, either version 3 of the License, or
//  (at your option) any later version.
//
//  vpncore is distributed in the hope that it will be useful,
//  but WITHOUT ANY WARRANTY; without even the implied warranty of
//  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
//  GNU General Public License for more details.
//
//  You should have received a copy of the GNU General Public License
//  along with LegacyCommon.  If not, see <https://www.gnu.org/licenses/>.
//

import Domain
import Foundation
import ProtonCoreFeatureFlags
import ProtonCoreNetworking
import VPNShared

#if canImport(UIKit)
    import UIKit

    fileprivate let deviceName = UIDevice.current.name
#else
    fileprivate let deviceName = Host.current().localizedName ?? ""
#endif

public final class CertificateRequest: Request {
    let publicKey: PublicKey
    let features: VPNConnectionFeatures?
    let isProTUN: Bool

    public init(publicKey: PublicKey, features: VPNConnectionFeatures?, isProTUN: Bool = false) {
        self.publicKey = publicKey
        self.features = features
        self.isProTUN = isProTUN
    }

    public var path: String {
        "/vpn/v1/certificate"
    }

    public var method: HTTPMethod {
        .post
    }

    public var parameters: [String: Any]? {
        var params = [
            "ClientPublicKey": publicKey.derRepresentation,
            "ClientPublicKeyMode": "EC",
            "DeviceName": deviceName,
            "Mode": "session",
        ] as [String: Any]

        // Saving features in certificate on ios only, because on macOS LocalAgent is available at all times
        if let features {
            params["Features"] = features.asDict
        }

        if let duration = CertificateConstants.certificateDuration {
            params["Duration"] = duration
        }

        // Prevents 409 conflict errors
        if VPNFeatureFlagType.certificateRefreshForceRenew.enabled {
            params["Renew"] = true
        }

        if isProTUN, FeatureFlagsRepository.shared.isProTUNEnabled {
            params["Experiments"] = ["Experiments": ["ProTUN": 1]]
        }

        return params
    }

    public var retryPolicy: ProtonRetryPolicy.RetryMode {
        .background
    }
}
