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

enum LogicalFeature: String, FeatureFlag {
    var category: String {
        "Logicals"
    }

    var feature: String {
        rawValue
    }

    case partnerLogicals = "PartnerLogicals"
    case perProtocolEntriesForStealth = "PerProtocolEntriesForStealth"
}

final class VPNLogicalServicesRequest: Request {
    /// Truncated ip as seen from VPN API
    let ip: String?

    /// Country codes, if available
    let countryCodes: [String]

    init(ip: String?, countryCodes: [String]) {
        self.ip = ip
        self.countryCodes = countryCodes
    }

    var path: String {
        var result = "/vpn/logicals" +
            "?WithTranslations=true"

        if isEnabled(LogicalFeature.partnerLogicals) {
            result += "&WithPartnerLogicals=1"
        }

        if isEnabled(LogicalFeature.perProtocolEntriesForStealth) {
            result += "&WithEntriesForProtocols=WireGuardTLS"
        }

        return result
    }

    var isAuth: Bool {
        return true
    }

    var header: [String: Any] {
        var result: [String: Any] = [:]

        if let ip = ip {
            result["x-pm-netzone"] = ip
        }

        if isEnabled(LogicalFeature.perProtocolEntriesForStealth), !countryCodes.isEmpty {
            result["x-pm-country"] = countryCodes.joined(separator: ", ")
        }

        return result
    }

    var retryPolicy: ProtonRetryPolicy.RetryMode {
        .background
    }
}
