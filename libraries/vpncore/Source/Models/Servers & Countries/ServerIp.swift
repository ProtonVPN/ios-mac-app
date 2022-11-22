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
import VPNShared

public class ServerIp: NSObject, NSCoding, Codable {
    public let id: String // "ID": "l8vWAXHBQNSQjPrxAr-D_BCxj1X0nW70HQRmAa-rIvzmKUA=="
    public let entryIp: String // "EntryIP": "95.215.61.163"
    public let exitIp: String // "ExitIP": "95.215.61.164"
    public let domain: String  // "Domain": "es-04.protonvpn.com"
    public let status: Int // "Status": 1  (1 - OK, 0 - under maintenance)
    public let label: String?
    public let x25519PublicKey: String?

    public func entryIp(using vpnProtocol: VpnProtocol) -> String? {
        guard let override = protocolEntries?.first(where: { $0.key == vpnProtocol }), let ip = override.value?.ipv4 else {
            return entryIp
        }

        return ip
    }

    public func overridePorts(using vpnProtocol: VpnProtocol) -> [Int]? {
        protocolEntries?[vpnProtocol]??.ports
    }

    /// API overrides for connection parameters when using a certain protocol.
    ///
    /// Given an entry `e` exists for a protocol `p` on `ServerIp` object `s`:
    /// 1. If `e.ipv4` is `nil`, `s` only supports `p`, and must use `s.entryIp` when connecting.
    /// 2. If `e.ipv4` is not `nil`, `s` supports all protocols. Client must use `e.ipv4` when connecting with `p`.
    /// 3. If `e.ports` is non-empty, client must choose from these ports when connecting, instead of ports from config.
    public let protocolEntries: [VpnProtocol: ProtocolEntry?]?

    public struct ProtocolEntry {
        public let ipv4: String?
        public let ports: [Int]?
    }
    
    override public var description: String {
        let entryOverrides: String = protocolEntries?.reduce(", with overrides for:\n", { partialResult, entry in
            partialResult + "\t\(entry.key.localizedString) => \(entry.value?.description ?? "(nil)")\n"
        }) ?? "\n"

        return  "ID      = \(id)\n" +
                "EntryIP = \(entryIp)\(entryOverrides)" +
                "ExitIP  = \(exitIp)\n" +
                "Domain  = \(domain)\n" +
                "Status  = \(status)\n" +
                "Label = \(label ?? "")\n" +
                "X25519PublicKey = \(x25519PublicKey ?? "")\n"
    }
    
    public init(id: String,
                entryIp: String,
                exitIp: String,
                domain: String,
                status: Int,
                label: String? = nil,
                x25519PublicKey: String? = nil,
                protocolEntries: [VpnProtocol: ProtocolEntry?]? = nil) {
        self.id = id
        self.entryIp = entryIp
        self.exitIp = exitIp
        self.domain = domain
        self.status = status
        self.label = label
        self.x25519PublicKey = x25519PublicKey
        self.protocolEntries = protocolEntries
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

        // looks like:
        // "EntryPerProtocol": {
        //     "WireGuardTLS": {"IPv4": "5.6.7.8"},
        //     "OpenVPNTCP": {"Ports": [22, 23]}
        //  }
        self.protocolEntries = try (dic["EntryPerProtocol"] as? [String: JSONDictionary?])?
            .reduce([VpnProtocol: ProtocolEntry?]()) { partialResult, keyPair in
                // Check if it's a vpn protocol that we recognize.
                guard let vpnProtocol = VpnProtocol.apiDescriptionsToProtocols[keyPair.key] else {
                    return partialResult
                }

                // API is allowed to include entries without overriding anything (see `protocolEntries` documentation)
                var protocolEntry: ProtocolEntry?
                if let protocolEntryDict = keyPair.value {
                    protocolEntry = try .init(dic: protocolEntryDict)
                }

                return partialResult.merging([vpnProtocol: protocolEntry]) { l, r in r }
            }

        super.init()
    }

    /// Used for testing purposes.
    public var asDict: [String: Any] {
        var result: [String: Any] = [
            "ID": id,
            "EntryIP": entryIp,
            "ExitIP": exitIp,
            "Domain": domain,
            "Status": status,
        ]

        if let x25519PublicKey = x25519PublicKey {
            result["X25519PublicKey"] = x25519PublicKey
        }
        if let label = label {
            result["Label"] = label
        }

        return result
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

extension ServerIp.ProtocolEntry {
    public init(dic: JSONDictionary) throws {
        self.ipv4 = dic.string("IPv4")
        self.ports = dic.intArray(key: "Ports")
    }
}

extension ServerIp.ProtocolEntry: CustomStringConvertible {
    public var description: String {
        var result = ""

        if let ipv4 {
            result += "\(ipv4)"
        }

        if let ports, !ports.isEmpty {
            if ports.count == 1, let first = ports.first {
                result += ":\(first)"
            } else {
                result += ":{\(ports.map(String.init).joined(separator: ", "))}"
            }
        }

        return result
    }
}
