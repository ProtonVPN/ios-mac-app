//
//  ServerIp.swift
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

public class ServerIp: NSObject, NSCoding, Codable {
    public let id: String // "ID": "l8vWAXHBQNSQjPrxAr-D_BCxj1X0nW70HQRmAa-rIvzmKUA=="
    public let entryIp: String // "EntryIP": "95.215.61.163"
    public let exitIp: String // "ExitIP": "95.215.61.164"
    public let domain: String  // "Domain": "es-04.protonvpn.com"
    public let status: Int // "Status": 1  (1 - OK, 0 - under maintenance)
    public let label: String?
    public let x25519PublicKey: String?

    public var supportsWireguard: Bool {
        if let x25519PublicKey = x25519PublicKey, !x25519PublicKey.isEmpty {
            return true
        }
        return false
    }
    
    override public var description: String {
        return
            "ID      = \(id)\n" +
            "EntryIP = \(entryIp)\n" +
            "ExitIP  = \(exitIp)\n" +
            "Domain  = \(domain)\n" +
            "Status  = \(status)\n" +
            "Label = \(label ?? "")\n" +
            "X25519PublicKey = \(x25519PublicKey ?? "")\n"
    }
    
    public init(id: String, entryIp: String, exitIp: String, domain: String, status: Int, label: String? = nil, x25519PublicKey: String? = nil) {
        self.id = id
        self.entryIp = entryIp
        self.exitIp = exitIp
        self.domain = domain
        self.status = status
        self.label = label
        self.x25519PublicKey = x25519PublicKey
        super.init()
    }
    
    public init(dic: JSONDictionary) throws {
        self.id = try dic.stringOrThrow(key: "ID")
        self.entryIp = try dic.stringOrThrow(key: "EntryIP")
        self.exitIp = try dic.stringOrThrow(key: "ExitIP")
        self.domain = try dic.stringOrThrow(key: "Domain")
        self.status = try dic.intOrThrow(key: "Status")
        self.label = dic["Label"] as? String
        self.x25519PublicKey = dic["X25519PublicKey"] as? String
        super.init()
    }
    
    // MARK: - NSCoding
    private enum CoderKey: String, CodingKey {
        case ID = "IDKey"
        case entryIp = "entryIpKey"
        case exitIp = "exitIpKey"
        case domain = "domainKey"
        case status = "statusKey"
        case label = "labelKey"
        case x25519PublicKey = "x25519PublicKey"
    }
    
    public required convenience init?(coder aDecoder: NSCoder) {
        guard let id = aDecoder.decodeObject(forKey: CoderKey.ID.rawValue) as? String,
            let entryIp = aDecoder.decodeObject(forKey: CoderKey.entryIp.rawValue) as? String,
            let exitIp = aDecoder.decodeObject(forKey: CoderKey.exitIp.rawValue) as? String,
            let domain = aDecoder.decodeObject(forKey: CoderKey.domain.rawValue) as? String else {
                return nil
        }
        let status = aDecoder.decodeInteger(forKey: CoderKey.status.rawValue)
        let label = aDecoder.decodeObject(forKey: CoderKey.label.rawValue) as? String
        let x25519PublicKey = aDecoder.decodeObject(forKey: CoderKey.x25519PublicKey.rawValue) as? String
        self.init(id: id, entryIp: entryIp, exitIp: exitIp, domain: domain, status: status, label: label, x25519PublicKey: x25519PublicKey)
    }
    
    public func encode(with aCoder: NSCoder) {
        aCoder.encode(id, forKey: CoderKey.ID.rawValue)
        aCoder.encode(entryIp, forKey: CoderKey.entryIp.rawValue)
        aCoder.encode(exitIp, forKey: CoderKey.exitIp.rawValue)
        aCoder.encode(domain, forKey: CoderKey.domain.rawValue)
        aCoder.encode(status, forKey: CoderKey.status.rawValue)
        aCoder.encode(label, forKey: CoderKey.label.rawValue)
        aCoder.encode(x25519PublicKey, forKey: CoderKey.x25519PublicKey.rawValue)
    }
    
    public var underMaintenance: Bool {
        return status == 0
    }
    
    // MARK: - Static functions
    
    // swiftlint:disable nsobject_prefer_isequal
    public static func == (lhs: ServerIp, rhs: ServerIp) -> Bool {
        return lhs.domain == rhs.domain
    }
    // swiftlint:enable nsobject_prefer_isequal
    
    // MARK: - Codable
    public required convenience init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CoderKey.self)
        
        let id = try container.decode(String.self, forKey: .ID)
        let entryIp = try container.decode(String.self, forKey: .entryIp)
        let exitIp = try container.decode(String.self, forKey: .exitIp)
        let domain = try container.decode(String.self, forKey: .domain)
        let status = try container.decode(Int.self, forKey: .status)
        let label = try container.decodeIfPresent(String.self, forKey: .label)
        let x25519PublicKey = try container.decodeIfPresent(String.self, forKey: .x25519PublicKey)
        
        self.init(id: id, entryIp: entryIp, exitIp: exitIp, domain: domain, status: status, label: label, x25519PublicKey: x25519PublicKey)
    }
    
    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CoderKey.self)
        
        try container.encode(id, forKey: .ID)
        try container.encode(entryIp, forKey: .entryIp)
        try container.encode(exitIp, forKey: .exitIp)
        try container.encode(domain, forKey: .domain)
        try container.encode(status, forKey: .status)
        try container.encode(label, forKey: .label)
        try container.encode(x25519PublicKey, forKey: .x25519PublicKey)
    }
}
