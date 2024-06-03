//
//  Created on 23/05/2024.
//
//  Copyright (c) 2024 Proton AG
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
import ProtonCoreAPIClient
import ProtonCoreNetworking
import Domain
import LocalFeatureFlags
import VPNShared
import Ergonomics

/// The following route is used to retrieve VPN server information, including scores for the best server to connect to depending on a user's proximity to a server and its load. To provide relevant scores even when connected to VPN, we send a truncated version of the user's public IP address. In keeping with our no-logs policy, this partial IP address is not stored on the server and is only used to fulfill this one-off API request.
public struct LogicalsRequest: Request {
    private static let protocolDescriptions = VpnProtocol.allCases.map(\.apiDescription).joined(separator: ",")

    /// Truncated ip as seen from VPN API
    let ip: TruncatedIp?

    /// Country codes, if available, to show relay IPs for specific countries
    let countryCodes: [String]

    /// Whether or not this request is just for the free logicals.
    let freeTier: Bool

    public init(ip: TruncatedIp?, countryCodes: [String], freeTier: Bool) {
        self.ip = ip
        self.countryCodes = countryCodes
        self.freeTier = freeTier
    }

    public var path: String {
        let path = URL(string: "/vpn/v1/logicals")!

        let queryItems: [URLQueryItem] = Array(
            ("WithTranslations", nil)
        )
        .appending(Array(("WithEntriesForProtocols", Self.protocolDescriptions)), if: shouldUseProtocolEntries)
        .appending(Array(("Tier", "0")), if: freeTier)

        return path.appendingQueryItems(queryItems).absoluteString
    }

    var shouldUseProtocolEntries: Bool {
        LocalFeatureFlags.isEnabled(LogicalFeature.perProtocolEntries)
    }

    public var isAuth: Bool {
        true
    }

    public var header: [String: Any] {
        var result: [String: Any] = [:]

        if let ip {
            result["x-pm-netzone"] = ip.value
        }

        if !countryCodes.isEmpty {
            result["x-pm-country"] = countryCodes.joined(separator: ", ")
        }

        return result
    }

    public var retryPolicy: ProtonRetryPolicy.RetryMode {
        .background
    }
}

extension Array<URLQueryItem> {
    init(_ elements: (name: String, value: String?)...) {
        self = elements.map { URLQueryItem(name: $0.name, value: $0.value) }
    }
}
