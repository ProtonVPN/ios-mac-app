//
//  ServerModel.swift
//  vpncore - Created on 26.06.19.
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

import Foundation

public class ServerModel: NSObject, NSCoding, Codable {
    
    public let id: String
    public let name: String
    public let domain: String
    public private(set) var load: Int
    public let entryCountryCode: String // use when feature.secureCore is true
    public let exitCountryCode: String
    public let tier: Int
    public private(set) var score: Double
    public let status: Int
    public let feature: ServerFeature
    public let city: String?
    public var ips: [ServerIp] = []
    public var location: ServerLocation
    
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
        "Location: \(location)\n"
    }
    
    public var hasCluster: Bool {
        return ips.count > 1
    }
    
    public var isFree: Bool {
        return name.lowercased().contains("free")
    }
    
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
    
    public var underMaintenance: Bool {
        return status == 0
    }
    
    public var hasExistingSession: Bool {
        return ips.filter { ip -> Bool in
            !ip.hasExistingSession
        }.isEmpty
    }
    
    public var serverType: ServerType {
        return isSecureCore ? .secureCore : .standard
    }
    
    public var entryCountry: String {
        return LocalizationUtility.countryName(forCode: self.entryCountryCode) ?? ""
    }
    
    public var exitCountry: String {
        return LocalizationUtility.countryName(forCode: self.exitCountryCode) ?? ""
    }
    
    public var country: String {
        return LocalizationUtility.countryName(forCode: self.exitCountryCode) ?? ""
    }
    
    public var countryCode: String {
        return self.exitCountryCode
    }
    
    public init(id: String, name: String, domain: String, load: Int, entryCountryCode: String, exitCountryCode: String, tier: Int, feature: ServerFeature, city: String?, ips: [ServerIp], score: Double, status: Int, location: ServerLocation) {
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
        super.init()
    }
    
    public init(dic: JSONDictionary) throws {
        id = try dic.stringOrThrow(key: "ID") //"ID": "-Bpgivr5H2qQ4-7gm3GtQPF9xwx9-VUA=="
        name = try dic.stringOrThrow(key: "Name") //"Name": "ES#1"
        domain = try dic.stringOrThrow(key: "Domain") //"Domain": "es-05.protonvpn.com"
        load = try dic.intOrThrow(key: "Load") //"Load": 13
        entryCountryCode = try dic.stringOrThrow(key: "EntryCountry") //"EntryCountry": "ES"
        exitCountryCode = try dic.stringOrThrow(key: "ExitCountry") //"ExitCountry": "ES" //this replace old countryCode
        tier = try dic.intOrThrow(key: "Tier") //"Tier": 2
        score = try dic.doubleOrThrow(key: "Score")  //"Score": 1
        status = try dic.intOrThrow(key: "Status") //"Status": 1,
        self.feature = try ServerFeature(rawValue: dic.intOrThrow(key: "Features")) //"Features": 12
        city = dic.string("City") //"City": "Zurich"
        self.location = try ServerLocation(dic: dic.jsonDictionaryOrThrow(key: "Location")) //"Location"
        super.init()
        try setupIps(fromArray: try dic.jsonArrayOrThrow(key: "Servers"))
    }
    
    public func matches(searchQuery: String) -> Bool {
        return country.lowercased().contains(searchQuery) || (self.isSecureCore ? self.entryCountry.contains(searchQuery) : false)
    }
    
    private func setupIps(fromArray array: [JSONDictionary]) throws {
        ips = []
        try array.forEach { ips.append(try ServerIp(dic: $0)) }
    }
    
    public func contains(domain: String) -> Bool {
        return !ips.filter { $0.domain == domain }.isEmpty
    }
    
    public func exitIp(forEntryIp entryIp: String) -> String? {
        for ip in ips where ip.entryIp == entryIp {
            return ip.exitIp
        }
        return nil
    }
    
    public func update(continousProperties: ContinuousServerProperties) {
        load = continousProperties.load
        score = continousProperties.score
    }
    
    // MARK: - NSCoding
    
    private enum CoderKey: String, CodingKey {
        case id = "id"
        case name = "name"
        case domain = "domain"
        case load = "load"
        case entryCountryCode = "entryCountryCode"
        case exitCountryCode = "exitCountryCode"
        case tier = "tier"
        case location = "location"
        case ips = "ips"
        case secureCore = "secureCore"
        case score = "score"
        case status = "status"
        case features = "features"
        case city = "city"
    }
    
    public required convenience init(coder aDecoder: NSCoder) {
        var ips: [ServerIp] = []
        if let ipsData = aDecoder.decodeObject(forKey: CoderKey.ips.rawValue) as? Data {
            ips = NSKeyedUnarchiver.unarchiveObject(with: ipsData) as? [ServerIp] ?? []
        }
        let feature = ServerFeature(rawValue: aDecoder.decodeInteger(forKey: CoderKey.features.rawValue))
        
        var location: ServerLocation = ServerLocation(lat: 0.0, long: 0.0)
        if let locationData = aDecoder.decodeObject(forKey: CoderKey.location.rawValue) as? Data {
            if let loc = (NSKeyedUnarchiver.unarchiveObject(with: locationData) as? ServerLocation) {
                location = loc
            }
        }
        
        self.init(id: aDecoder.decodeObject(forKey: CoderKey.id.rawValue) as! String,
                  name: aDecoder.decodeObject(forKey: CoderKey.name.rawValue) as! String,
                  domain: aDecoder.decodeObject(forKey: CoderKey.domain.rawValue) as! String,
                  load: aDecoder.decodeInteger(forKey: CoderKey.load.rawValue),
                  entryCountryCode: aDecoder.decodeObject(forKey: CoderKey.entryCountryCode.rawValue) as! String,
                  exitCountryCode: aDecoder.decodeObject(forKey: CoderKey.exitCountryCode.rawValue) as! String,
                  tier: aDecoder.decodeInteger(forKey: CoderKey.tier.rawValue),
                  feature: feature,
                  city: aDecoder.decodeObject(forKey: CoderKey.city.rawValue) as? String,
                  ips: ips,
                  score: aDecoder.decodeDouble(forKey: CoderKey.score.rawValue),
                  status: aDecoder.decodeInteger(forKey: CoderKey.status.rawValue),
                  location: location)
    }
    
    public func encode(with aCoder: NSCoder) {
        aCoder.encode(id, forKey: CoderKey.id.rawValue)
        aCoder.encode(name, forKey: CoderKey.name.rawValue)
        aCoder.encode(domain, forKey: CoderKey.domain.rawValue)
        aCoder.encode(load, forKey: CoderKey.load.rawValue)
        aCoder.encode(entryCountryCode, forKey: CoderKey.entryCountryCode.rawValue)
        aCoder.encode(exitCountryCode, forKey: CoderKey.exitCountryCode.rawValue)
        aCoder.encode(tier, forKey: CoderKey.tier.rawValue)
        aCoder.encode(score, forKey: CoderKey.score.rawValue)
        aCoder.encode(status, forKey: CoderKey.status.rawValue)
        aCoder.encode(feature.rawValue, forKey: CoderKey.features.rawValue)
        aCoder.encode(city, forKey: CoderKey.city.rawValue)
        
        let ipsData = NSKeyedArchiver.archivedData(withRootObject: ips)
        let locationData = NSKeyedArchiver.archivedData(withRootObject: location)
        
        aCoder.encode(ipsData, forKey: CoderKey.ips.rawValue)
        aCoder.encode(locationData, forKey: CoderKey.location.rawValue)
    }
    
    // MARK: - Codable
    
    public required convenience init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CoderKey.self)
        
        let ipsData = try container.decode(Data.self, forKey: CoderKey.ips)
        let ips: [ServerIp] = NSKeyedUnarchiver.unarchiveObject(with: ipsData) as? [ServerIp] ?? []

        let feature = ServerFeature(rawValue: try container.decode(Int.self, forKey: CoderKey.features))
        
        let locationData = try container.decode(Data.self, forKey: CoderKey.location)
        let location = (NSKeyedUnarchiver.unarchiveObject(with: locationData) as? ServerLocation) ?? ServerLocation(lat: 0, long: 0)
        
        self.init(id: try container.decode(String.self, forKey: CoderKey.id),
                  name: try container.decode(String.self, forKey: CoderKey.name),
                  domain: try container.decode(String.self, forKey: CoderKey.domain),
                  load: try container.decode(Int.self, forKey: CoderKey.load),
                  entryCountryCode: try container.decode(String.self, forKey: CoderKey.entryCountryCode),
                  exitCountryCode: try container.decode(String.self, forKey: CoderKey.exitCountryCode),
                  tier: try container.decode(Int.self, forKey: CoderKey.tier),
                  feature: feature,
                  city: try container.decodeIfPresent(String.self, forKey: CoderKey.city),
                  ips: ips,
                  score: try container.decode(Double.self, forKey: CoderKey.score),
                  status: try container.decode(Int.self, forKey: CoderKey.status),
                  location: location)
    }
    
    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CoderKey.self)
        
        try container.encode(id, forKey: .id)
        try container.encode(name, forKey: .name)
        try container.encode(domain, forKey: .domain)
        try container.encode(load, forKey: .load)
        try container.encode(entryCountryCode, forKey: .entryCountryCode)
        try container.encode(exitCountryCode, forKey: .exitCountryCode)
        try container.encode(tier, forKey: .tier)
        try container.encode(score, forKey: .score)
        try container.encode(status, forKey: .status)
        try container.encode(feature.rawValue, forKey: .features)
        try container.encode(city, forKey: .city)
        
        let ipsData = NSKeyedArchiver.archivedData(withRootObject: ips)
        let locationData = NSKeyedArchiver.archivedData(withRootObject: location)
        
        try container.encode(ipsData, forKey: .ips)
        try container.encode(locationData, forKey: .location)
    }
    
    // MARK: - Static functions
    
    // swiftlint:disable nsobject_prefer_isequal
    public static func == (lhs: ServerModel, rhs: ServerModel) -> Bool {
        return lhs.name == rhs.name
    }
    // swiftlint:enable nsobject_prefer_isequal
    
    public static func < (lhs: ServerModel, rhs: ServerModel) -> Bool {
        // Servers whose name contains word free come
        // first in the ordering.
        if let order = orderForMatch("FREE", lhs: lhs.name, rhs: rhs.name) {
            return order
        }
        
        // we split the name into the server name and the sequence number
        let serverModel1Array = lhs.name.split(separator: "#")
        let serverModel2Array = rhs.name.split(separator: "#")

        // if server names don't have the sequence numbers, it's enough to compare the names
        if serverModel1Array.count == 2 && serverModel2Array.count == 2 {
            if serverModel1Array[0] != serverModel2Array[0] {
                return serverModel1Array[0] < serverModel2Array[0]
            } else {
                // some of the server sequence numbers might have the trailing "-TOR" - we strip it
                let number1 = Int(String(serverModel1Array[1]).split(separator: "-")[0]) ?? 0
                let number2 = Int(String(serverModel2Array[1]).split(separator: "-")[0]) ?? 0
                return number1 < number2
            }
        } else {
            return lhs.name < rhs.name
        }
    }
    
    // MARK: - Private static functions
    private static func orderForMatch(_ regex: String, lhs: String, rhs: String) -> Bool? {
        let leftMatches = lhs.hasMatches(for: regex)
        let rightMatches = rhs.hasMatches(for: regex)
        
        if leftMatches, rightMatches {
            return lhs < rhs
        } else if leftMatches, !rightMatches {
            return true
        } else if !leftMatches, rightMatches {
            return false
        }
        return nil
    }
}
