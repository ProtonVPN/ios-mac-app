//
//  VPNLogicalServicesRequest.swift
//  vpncore - Created on 30/04/2020.
//
//  Copyright (c) 2019 Proton Technologies AG
//
//  This file is part of vpncore.
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
//  along with vpncore.  If not, see <https://www.gnu.org/licenses/>.
//

import ProtonCore_Networking
import LocalFeatureFlags
import VPNShared

final class VPNLogicalServicesRequest: Request {
    private static let protocolDescriptions = VpnProtocol.allCases.map(\.apiDescription).joined(separator: ",")

    /// Truncated ip as seen from VPN API
    let ip: String?

    /// Country codes, if available, to show relay IPs for specific countries
    let countryCodes: [String]

    init(ip: String?, countryCodes: [String]) {
        self.ip = ip
        self.countryCodes = countryCodes
    }

    var path: String {
        let path = URL(string: "/vpn/logicals")!

        var queryItems: [URLQueryItem] = [
            .init(name: "WithTranslations", value: nil),
            .init(name: "WithPartnerLogicals", value: "1"),
        ]

        if isEnabled(LogicalFeature.perProtocolEntries) {
            queryItems.append(.init(name: "WithEntriesForProtocols", value: Self.protocolDescriptions))
        }

        return path.appendingQueryItems(queryItems).absoluteString
    }

    var isAuth: Bool {
        return true
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
