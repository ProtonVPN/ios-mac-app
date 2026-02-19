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

import Foundation

import Domain
import Ergonomics
import Localization
import Strings
import VPNAppCore
import VPNShared

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

    var isFree: Bool { tier == 0 }

    /// The server name, split into the name prefix and sequence number (if it exists).
    var serverNameComponents: ServerNameComponents { .init(name: name) }

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

    init(dic: JSONDictionary) throws {
        try self.init(
            id: dic.stringOrThrow(key: "ID"), // "ID": "-Bpgivr5H2qQ4-7gm3GtQPF9xwx9-VUA=="
            name: dic.stringOrThrow(key: "Name"), // "Name": "ES#1"
            domain: dic.stringOrThrow(key: "Domain"), // "Domain": "es-05.protonvpn.com"
            load: Int(dic.doubleOrThrow(key: "Load")), // "Load": 13
            entryCountryCode: dic.stringOrThrow(key: "EntryCountry"), // "EntryCountry": "ES"
            exitCountryCode: dic.stringOrThrow(key: "ExitCountry"), // "ExitCountry": "ES" //this replace old countryCode
            tier: dic.intOrThrow(key: "Tier"), // "Tier": 2
            feature: ServerFeature(rawValue: dic.intOrThrow(key: "Features")), // "Features": 12
            city: dic.string("City"), // "City": "Zurich"
            state: dic.string("State"), // "State": "Colorado"
            ips: dic.jsonArrayOrThrow(key: "Servers").map { try ServerIp(dic: $0) },
            score: dic.doubleOrThrow(key: "Score"), // "Score": 1
            status: dic.intOrThrow(key: "Status"), // "Status": 1,
            location: ServerLocation(dic: dic.jsonDictionaryOrThrow(key: "Location")), // "Location"
            hostCountry: dic.string("HostCountry"),
            translatedCity: (dic["Translations"] as? AnyObject)?["City"] as? String,
            gatewayName: dic.string("GatewayName")
        )
    }

    /// Used for testing purposes.
    var asDict: [String: Any] {
        var result: [String: Any] = [
            "ID": id,
            "Name": name,
            "Domain": domain,
            "Load": load,
            "EntryCountry": entryCountryCode,
            "ExitCountry": exitCountryCode,
            "Tier": tier,
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

    static func < (lhs: ServerModel, rhs: ServerModel) -> Bool {
        // Servers whose name contains word Free come
        // first in the ordering.
        let lhsIsFree = lhs.isFree
        let rhsIsFree = rhs.isFree
        if lhsIsFree, !rhsIsFree {
            return true
        }
        if !lhsIsFree, rhsIsFree {
            return false
        }

        let (lhsSplitName, rhsSplitName) = (lhs.serverNameComponents, rhs.serverNameComponents)
        guard let lhsSeqNum = lhsSplitName.sequence, let rhsSeqNum = rhsSplitName.sequence else {
            // if server names don't have the sequence numbers, it's enough to compare the names
            return lhs.name < rhs.name
        }
        guard lhsSplitName.name == rhsSplitName.name else {
            return lhsSplitName.name < rhsSplitName.name
        }
        return lhsSeqNum < rhsSeqNum
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
