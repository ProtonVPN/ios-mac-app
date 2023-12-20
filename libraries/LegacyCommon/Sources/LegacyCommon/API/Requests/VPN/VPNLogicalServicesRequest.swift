//
//  VPNLogicalServicesRequest.swift
//  vpncore - Created on 30/04/2020.
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

import Foundation
import ProtonCoreNetworking
import LocalFeatureFlags
import VPNShared

final class VPNLogicalServicesRequest: Request {
    private static let protocolDescriptions = VpnProtocol.allCases.map(\.apiDescription).joined(separator: ",")

    /// Truncated ip as seen from VPN API
    let ip: String?

    /// Country codes, if available, to show relay IPs for specific countries
    let countryCodes: [String]

    /// Whether or not this request is just for the free logicals.
    let freeTier: Bool

    init(ip: String?, countryCodes: [String], freeTier: Bool) {
        self.ip = ip
        self.countryCodes = countryCodes
        self.freeTier = freeTier
    }

    var path: String {
        let path = URL(string: "/vpn/logicals")!

        let queryItems: [URLQueryItem] = Array(
            ("WithTranslations", nil),
            ("WithPartnerLogicals", "1")
        )
        .appending(Array(("WithEntriesForProtocols", Self.protocolDescriptions)), if: shouldUseProtocolEntries)
        .appending(Array(("Tier", "0")), if: freeTier)

        return path.appendingQueryItems(queryItems).absoluteString
    }

    var shouldUseProtocolEntries: Bool {
        LocalFeatureFlags.isEnabled(LogicalFeature.perProtocolEntries)
    }

    var isAuth: Bool {
        true
    }

    var header: [String: Any] {
        var result: [String: Any] = [:]

        if let ip = ip {
            result["x-pm-netzone"] = ip
        }

        if !countryCodes.isEmpty {
            result["x-pm-country"] = countryCodes.joined(separator: ", ")
        }

        return result
    }

    var retryPolicy: ProtonRetryPolicy.RetryMode {
        .background
    }
}

extension Array<URLQueryItem> {
    init(_ elements: (name: String, value: String?)...) {
        self = elements.map { URLQueryItem(name: $0.name, value: $0.value) }
    }
}
