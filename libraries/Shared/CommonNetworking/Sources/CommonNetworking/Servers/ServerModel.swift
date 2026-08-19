//
//  ServerModel.swift
//  vpncore - Created on 26.06.19.
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

import Domain
import Ergonomics
import Foundation
import Localization
import VPNAppCore

public extension ServerModel {
    var description: String {
        "ID: \(id)\n" +
            "Name: \(name)\n" +
            "Domain: \(domain)\n" +
            "Load: \(load)\n" +
            "EntryCountry: \(entryCountryCode)\n" +
            "ExitCountry: \(exitCountryCode)\n" +
            "Tier: \(tier)\n" +
            "Score: \(score)\n" +
            "Status: \(status)\n" +
            "Feature: \(feature)\n" +
            "City: \(String(describing: city))\n" +
            "IPs: \(ips)\n" +
            "Location: \(location)\n" +
            "HostCountry: \(String(describing: hostCountry))\n" +
            "TranslatedCity: \(String(describing: translatedCity))\n" +
            "gatewayName: \(String(describing: gatewayName))\n"
    }

    var logDescription: String {
        "\(name) (\(domain), load: \(load))"
    }

    var hasCluster: Bool {
        ips.count > 1
    }

    var isFree: Bool {
        tier.isFree
    }

    /// The server name, split into the name prefix and sequence number (if it exists).
    var serverNameComponents: ServerNameComponents {
        .init(name: name)
    }

    var isSecureCore: Bool {
        feature.contains(.secureCore)
    }

    var hasSecureCore: Bool {
        feature.rawValue > 0
    }

    var supportsP2P: Bool {
        feature.contains(.p2p)
    }

    var supportsTor: Bool {
        feature.contains(.tor)
    }

    var supportsStreaming: Bool {
        feature.contains(.streaming)
    }

    var underMaintenance: Bool {
        status == 0
    }

    var serverType: ServerType {
        isSecureCore ? .secureCore : .standard
    }

    var entryCountry: String {
        LocalizationUtility.default.countryName(forCode: entryCountryCode) ?? ""
    }

    var exitCountry: String {
        LocalizationUtility.default.countryName(forCode: exitCountryCode) ?? ""
    }

    var country: String {
        LocalizationUtility.default.countryName(forCode: exitCountryCode) ?? ""
    }

    var countryCode: String {
        exitCountryCode
    }

    var isVirtual: Bool {
        if let hostCountry, !hostCountry.isEmpty {
            return true
        }

        return false
    }

    func supports(vpnProtocol: VpnProtocol) -> Bool {
        ips.contains { $0.supports(vpnProtocol: vpnProtocol) }
    }

    func supports(connectionProtocol: ConnectionProtocol, smartProtocolConfig: SmartProtocolConfig) -> Bool {
        if let vpnProtocol = connectionProtocol.vpnProtocol {
            return supports(vpnProtocol: vpnProtocol)
        }

        return ips.contains {
            $0.supports(connectionProtocol: connectionProtocol, smartProtocolConfig: smartProtocolConfig)
        }
    }

    #if DEBUG
        var asDict: [String: Any] {
            var result: [String: Any] = [
                "ID": id,
                "Name": name,
                "Domain": domain,
                "Load": load,
                "EntryCountry": entryCountryCode,
                "ExitCountry": exitCountryCode,
                "Tier": tier.rawValue,
                "Score": score,
                "Status": status,
                "Features": feature.rawValue,
                "Location": location.asDict,
                "Servers": ips.map(\.asDict),
            ]

            if let city {
                result["City"] = city
            }

            if let state {
                result["State"] = state
            }
            if let hostCountry {
                result["HostCountry"] = hostCountry
            }
            if let translatedCity {
                result["Translations"] = [
                    "City": translatedCity,
                ]
            }
            if let gatewayName {
                result["GatewayName"] = gatewayName
            }

            return result
        }
    #endif

    func matches(searchQuery: String) -> Bool {
        let query = searchQuery.lowercased()

        if isSecureCore {
            return entryCountry.lowercased().contains(query)
        }

        if name.lowercased().contains(query) {
            return true
        }

        if country.lowercased().contains(query) {
            return true
        }

        if let city, city.lowercased().contains(query) {
            return true
        }

        if let translatedCity, translatedCity.lowercased().contains(query) {
            return true
        }

        return false
    }
}

public struct ServerListUpdateNotification: TypedNotification {
    public static let name = Notification.Name("ProtonVPN.ServerListUpdate")
    public let data: ServerListUpdate

    public init(data: ServerListUpdate) {
        self.data = data
    }
}

public enum ServerListUpdate {
    case servers
    case loads
}
