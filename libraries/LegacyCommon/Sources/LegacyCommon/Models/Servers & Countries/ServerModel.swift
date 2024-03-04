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
import Strings
import VPNShared
import VPNAppCore

public class ServerModel: NSObject, NSCoding, Codable {
    
    public let id: String
    public let name: String
    public let domain: String
    public private(set) var load: Int
    public let entryCountryCode: String // use when feature.secureCore is true
    public let exitCountryCode: String
    public let tier: Int
    public private(set) var score: Double
    public private(set) var status: Int
    public let feature: ServerFeature
    public let city: String?
    public let ips: [ServerIp]
    public var location: ServerLocation
    public let hostCountry: String?
    public let translatedCity: String?
    public let gatewayName: String?
    
    override public var description: String {
        return
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
    
    public var logDescription: String {
        return "\(name) (\(domain), load: \(load))"
    }
    
    public var hasCluster: Bool {
        return ips.count > 1
    }
    
    public lazy var isFree: Bool = {
        tier == 0
    }()

    /// The server name, split into the name prefix and sequence number (if it exists).
    public lazy var splitName: (serverName: String, sequenceNumber: Int?) = {
        let nameArray = name.split(separator: "#")
        guard nameArray.count == 2 else {
            return (name, nil)
        }
        let serverName = String(nameArray[0])
        // some of the server sequence numbers might have the trailing "-TOR" - we strip it
        guard let numberString = nameArray[1].split(separator: "-").first, let number = Int(String(numberString)) else {
            return (serverName, 0)
        }
        return (serverName, number)
    }()
    
    public var isSecureCore: Bool {
        return self.feature.contains(.secureCore)
    }
    
    public var hasSecureCore: Bool {
        return self.feature.rawValue > 0
    }
    
    public var supportsP2P: Bool {
        return self.feature.contains(.p2p)
    }

    public var supportsTor: Bool {
        return self.feature.contains(.tor)
    }

    public var supportsStreaming: Bool {
        return self.feature.contains(.streaming)
    }
    
    public var underMaintenance: Bool {
        return status == 0
    }
    
    public var serverType: ServerType {
        return isSecureCore ? .secureCore : .standard
    }
    
    public var entryCountry: String {
        return LocalizationUtility.default.countryName(forCode: self.entryCountryCode) ?? ""
    }
    
    public var exitCountry: String {
        return LocalizationUtility.default.countryName(forCode: self.exitCountryCode) ?? ""
    }
    
    public var country: String {
        return LocalizationUtility.default.countryName(forCode: self.exitCountryCode) ?? ""
    }
    
    public var countryCode: String {
        return self.exitCountryCode
    }

    public var isVirtual: Bool {
        if let hostCountry = hostCountry, !hostCountry.isEmpty {
            return true
        }

        return false
    }

    public func supports(vpnProtocol: VpnProtocol) -> Bool {
        ips.contains { $0.supports(vpnProtocol: vpnProtocol) }
    }

    public func supports(connectionProtocol: ConnectionProtocol,
                         smartProtocolConfig: SmartProtocolConfig) -> Bool {
        if let vpnProtocol = connectionProtocol.vpnProtocol {
            return supports(vpnProtocol: vpnProtocol)
        }

        return ips.contains {
            $0.supports(connectionProtocol: connectionProtocol,
                        smartProtocolConfig: smartProtocolConfig)
        }
    }

    public init(id: String, name: String, domain: String, load: Int, entryCountryCode: String, exitCountryCode: String, tier: Int, feature: ServerFeature, city: String?, ips: [ServerIp], score: Double, status: Int, location: ServerLocation, hostCountry: String?, translatedCity: String?, gatewayName: String?) {
        self.id = id
        self.name = name
        self.domain = domain
        self.load = load
        self.exitCountryCode = exitCountryCode
        self.entryCountryCode = entryCountryCode
        self.tier = tier
        self.feature = feature
        self.city = city
        self.ips = ips
        self.score = score
        self.status = status
        self.location = location
        self.hostCountry = hostCountry
        self.translatedCity = translatedCity
        self.gatewayName = gatewayName
        super.init()
    }
    
    public init(dic: JSONDictionary) throws {
        id = try dic.stringOrThrow(key: "ID") // "ID": "-Bpgivr5H2qQ4-7gm3GtQPF9xwx9-VUA=="
        name = try dic.stringOrThrow(key: "Name") // "Name": "ES#1"
        domain = try dic.stringOrThrow(key: "Domain") // "Domain": "es-05.protonvpn.com"
        load = try Int(dic.doubleOrThrow(key: "Load")) // "Load": 13
        entryCountryCode = try dic.stringOrThrow(key: "EntryCountry") // "EntryCountry": "ES"
        exitCountryCode = try dic.stringOrThrow(key: "ExitCountry") // "ExitCountry": "ES" //this replace old countryCode
        tier = try dic.intOrThrow(key: "Tier") // "Tier": 2
        score = try dic.doubleOrThrow(key: "Score")  // "Score": 1
        status = try dic.intOrThrow(key: "Status") // "Status": 1,
        self.feature = try ServerFeature(rawValue: dic.intOrThrow(key: "Features")) // "Features": 12
        city = dic.string("City") // "City": "Zurich"
        self.location = try ServerLocation(dic: dic.jsonDictionaryOrThrow(key: "Location")) // "Location"
        hostCountry = dic.string("HostCountry")
        translatedCity = (dic["Translations"] as? AnyObject)?["City"] as? String
        ips = try dic.jsonArrayOrThrow(key: "Servers").map { try ServerIp(dic: $0) }
        gatewayName = dic.string("GatewayName")
        super.init()
    }

    /// Used for testing purposes.
    public var asDict: [String: Any] {
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
            "Servers": ips.map { $0.asDict },
        ]

        if let city {
            result["City"] = city
        }
        if let hostCountry {
            result["HostCountry"] = hostCountry
        }
        if let translatedCity {
            result["Translations"] = [
                "City": translatedCity
            ]
        }
        if let gatewayName {
            result["GatewayName"] = gatewayName
        }

        return result
    }
    
    public func matches(searchQuery: String) -> Bool {
        let query = searchQuery.lowercased()
        
        if isSecureCore {
            return self.entryCountry.lowercased().contains(query)
        }
        
        if name.lowercased().contains(query) {
            return true
        }
        
        if country.lowercased().contains(query) {
            return true
        }
        
        if let city = self.city, city.lowercased().contains(query) {
            return true
        }

        if let translatedCity = self.translatedCity, translatedCity.lowercased().contains(query) {
            return true
        }
        
        return false
    }

    public func update(continuousProperties: ContinuousServerProperties) {
        load = continuousProperties.load
        score = continuousProperties.score
        status = continuousProperties.status
    }
    
    // MARK: - NSCoding
    
    private enum CodingKeys: String, CodingKey {
        case id = "id"
        case name = "name"
        case domain = "domain"
        case load = "load"
        case entryCountryCode = "entryCountryCode"
        case exitCountryCode = "exitCountryCode"
        case tier = "tier"
        case location = "location"
        case ips = "ips"
        case score = "score"
        case status = "status"
        case feature = "features"
        case city = "city"
        case hostCountry = "hostCountry"
        case translatedCity = "translatedCity"
        case gatewayName = "gatewayName"
    }

    public required convenience init(coder aDecoder: NSCoder) {
        var ips: [ServerIp] = []
        if let ipsData = aDecoder.decodeObject(forKey: CodingKeys.ips.rawValue) as? Data {
            ips = NSKeyedUnarchiver.unarchiveObject(with: ipsData) as? [ServerIp] ?? []
        }
        let feature = ServerFeature(rawValue: aDecoder.decodeInteger(forKey: CodingKeys.feature.rawValue))
        
        var location: ServerLocation = ServerLocation(lat: 0.0, long: 0.0)
        if let locationData = aDecoder.decodeObject(forKey: CodingKeys.location.rawValue) as? Data {
            if let loc = (NSKeyedUnarchiver.unarchiveObject(with: locationData) as? ServerLocation) {
                location = loc
            }
        }
        
        self.init(id: aDecoder.decodeObject(forKey: CodingKeys.id.rawValue) as! String,
                  name: aDecoder.decodeObject(forKey: CodingKeys.name.rawValue) as! String,
                  domain: aDecoder.decodeObject(forKey: CodingKeys.domain.rawValue) as! String,
                  load: aDecoder.decodeInteger(forKey: CodingKeys.load.rawValue),
                  entryCountryCode: aDecoder.decodeObject(forKey: CodingKeys.entryCountryCode.rawValue) as! String,
                  exitCountryCode: aDecoder.decodeObject(forKey: CodingKeys.exitCountryCode.rawValue) as! String,
                  tier: aDecoder.decodeInteger(forKey: CodingKeys.tier.rawValue),
                  feature: feature,
                  city: aDecoder.decodeObject(forKey: CodingKeys.city.rawValue) as? String,
                  ips: ips,
                  score: aDecoder.decodeDouble(forKey: CodingKeys.score.rawValue),
                  status: aDecoder.decodeInteger(forKey: CodingKeys.status.rawValue),
                  location: location,
                  hostCountry: aDecoder.decodeObject(forKey: CodingKeys.hostCountry.rawValue) as? String,
                  translatedCity: aDecoder.decodeObject(forKey: CodingKeys.translatedCity.rawValue) as? String,
                  gatewayName: aDecoder.decodeObject(forKey: CodingKeys.gatewayName.rawValue) as? String
        )
    }
    
    public func encode(with aCoder: NSCoder) {
        log.assertionFailure("We migrated away from NSCoding, this method shouldn't be used anymore")
    }
    
    // MARK: - Codable
    
    public required convenience init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)

        let ips: [ServerIp]
        if let decodedIPs = try? container.decode([ServerIp].self, forKey: CodingKeys.ips) {
            ips = decodedIPs
        } else if let ipsData = try? container.decode(Data.self, forKey: CodingKeys.ips),
                  let unarchivedObject = NSKeyedUnarchiver.unarchiveObject(with: ipsData) as? [ServerIp] {
            ips = unarchivedObject
        } else {
            ips = []
        }

        let feature = ServerFeature(rawValue: try container.decode(Int.self, forKey: CodingKeys.feature))

        let location: ServerLocation
        if let decodedLocation = try? container.decode(ServerLocation.self, forKey: CodingKeys.location) {
            location = decodedLocation
        } else if let locationData = try? container.decode(Data.self, forKey: CodingKeys.location),
                  let unarchivedObject = try? NSKeyedUnarchiver.unarchivedObject(ofClass: ServerLocation.self, from: locationData) {
            location = unarchivedObject
        } else {
            location = ServerLocation(lat: 0, long: 0)
        }

        self.init(id: try container.decode(String.self, forKey: CodingKeys.id),
                  name: try container.decode(String.self, forKey: CodingKeys.name),
                  domain: try container.decode(String.self, forKey: CodingKeys.domain),
                  load: try container.decode(Int.self, forKey: CodingKeys.load),
                  entryCountryCode: try container.decode(String.self, forKey: CodingKeys.entryCountryCode),
                  exitCountryCode: try container.decode(String.self, forKey: CodingKeys.exitCountryCode),
                  tier: try container.decode(Int.self, forKey: CodingKeys.tier),
                  feature: feature,
                  city: try container.decodeIfPresent(String.self, forKey: CodingKeys.city),
                  ips: ips,
                  score: try container.decode(Double.self, forKey: CodingKeys.score),
                  status: try container.decode(Int.self, forKey: CodingKeys.status),
                  location: location,
                  hostCountry: try container.decodeIfPresent(String.self, forKey: CodingKeys.hostCountry),
                  translatedCity: try container.decodeIfPresent(String.self, forKey: CodingKeys.translatedCity),
                  gatewayName: try container.decodeIfPresent(String.self, forKey: CodingKeys.gatewayName)
        )
    }
    
    // MARK: - Static functions
    
    // swiftlint:disable nsobject_prefer_isequal
    public static func == (lhs: ServerModel, rhs: ServerModel) -> Bool {
        return lhs.name == rhs.name
    }
    // swiftlint:enable nsobject_prefer_isequal
    
    public static func < (lhs: ServerModel, rhs: ServerModel) -> Bool {
        // Servers whose name contains word Free come
        // first in the ordering.
        let lhsIsFree = lhs.isFree
        let rhsIsFree = rhs.isFree
        let lhsIsPartner = lhs.feature.contains(.partner)
        let rhsIsPartner = rhs.feature.contains(.partner)
        if lhsIsFree, rhsIsFree {
            if lhsIsPartner, rhsIsPartner {
                return lhs.name < rhs.name
            }
            if lhsIsPartner, !rhsIsPartner {
                return false
            }
            if !lhsIsPartner, rhsIsPartner {
                return true
            }
        }
        if lhsIsFree, !rhsIsFree {
            return true
        }
        if !lhsIsFree, rhsIsFree {
            return false
        }

        let (lhsSplitName, rhsSplitName) = (lhs.splitName, rhs.splitName)
        guard let lhsSeqNum = lhsSplitName.sequenceNumber, let rhsSeqNum = rhsSplitName.sequenceNumber else {
            // if server names don't have the sequence numbers, it's enough to compare the names
            return lhs.name < rhs.name
        }
        guard lhsSplitName.serverName == rhsSplitName.serverName else {
            return lhsSplitName.serverName < rhsSplitName.serverName
        }
        return lhsSeqNum < rhsSeqNum
    }
}
