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
    public let entryIp: String? // "EntryIP": "95.215.61.163"
    public let exitIp: String // "ExitIP": "95.215.61.164"
    public let domain: String  // "Domain": "es-04.protonvpn.com"
    public let status: Int // "Status": 1  (1 - OK, 0 - under maintenance)
    public let label: String?
    public let x25519PublicKey: String?

    /// API overrides for connection parameters when using a certain protocol.
    ///
    /// Given an entry `e` exists for a protocol `p` on `ServerIp` object `s`:
    /// 1. If `e.ipv4` is `nil`, `s` only supports `p`, and must use `s.entryIp` when connecting.
    /// 2. If `e.ipv4` is not `nil`, `s` supports all protocols. Client must use `e.ipv4` when connecting with `p`.
    /// 3. If `e.ports` is non-empty, client must choose from these ports when connecting, instead of ports from config.
    public let protocolEntries: [VpnProtocol: ProtocolEntry?]?

    public struct ProtocolEntry: Codable {
        public let ipv4: String?
        public let ports: [Int]?
    }
    
    override public var description: String {
        let entryOverrides: String = protocolEntries?.reduce(", with overrides for:\n", { partialResult, entry in
            partialResult + "\t\(entry.key.localizedString) => \(entry.value?.description ?? "(nil)")\n"
        }) ?? "\n"

        return  "ID      = \(id)\n" +
                "EntryIP = \(entryIp ?? "(nil)")\(entryOverrides)" +
                "ExitIP  = \(exitIp)\n" +
                "Domain  = \(domain)\n" +
                "Status  = \(status)\n" +
                "Label = \(label ?? "")\n" +
                "X25519PublicKey = \(x25519PublicKey ?? "")\n"
    }
    
    public init(id: String,
                entryIp: String?,
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
        self.exitIp = try dic.stringOrThrow(key: "ExitIP")
        self.domain = try dic.stringOrThrow(key: "Domain")
        self.status = try dic.intOrThrow(key: "Status")
        self.entryIp = dic.string("EntryIP")
        self.label = dic.string("Label")
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
                    log.error("Unrecognized VPN protocol from API: \(keyPair.key)")
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

    /// Determine the appropriate entry IP to use for the given `ServerIp` object and
    /// protocol, according to the `entryIp` and `protocolEntries` properties.
    /// - Warning: The `entryIp` property is nullable, be careful when changing this function.
    public func entryIp(using vpnProtocol: VpnProtocol) -> String? {
        // Check to see if the given server IP contains a per-protocol override.
        guard let override = protocolEntries?.first(where: { $0.key == vpnProtocol }) else {
            // An override does not exist on the server IP for the current protocol.
            // If the server IP contains an override where an IP address is nil, then it means that this server IP only
            // supports protocols for which there is an entry in the overrides list. Thus, if this guard fails, then on
            // this server IP there is no entry IP that supports `vpnProtocol`.
            guard protocolEntries?.contains(where: { $0.value?.ipv4 == nil }) != true else {
                return nil
            }

            // An override doesn't exist, and no overrides are present that have a null entry IP.
            // This is the default case, return the normal entry IP.
            return entryIp
        }

        // An override for the given protocol exists, but doesn't define an IP address. This means
        // that the ServerIp in question supports this protocol, but should connect with `entryIp`.
        guard let ip = override.value?.ipv4 else {
            return entryIp
        }

        // An override for the given protocol exists, and the IP address is defined. Return this
        // overridden IP address.
        return ip
    }

    public func supports(vpnProtocol: VpnProtocol) -> Bool {
        entryIp(using: vpnProtocol) != nil
    }

    /// Depending on the smart protocol config, we might only support a subset of the protocols.
    /// If the connection protocol is smart protocol, this function returns true if any of the
    /// protocols in the smart config are supported by this server ip.
    public func supports(connectionProtocol: ConnectionProtocol, smartProtocolConfig: SmartProtocolConfig) -> Bool {
        if let vpnProtocol = connectionProtocol.vpnProtocol {
            return supports(vpnProtocol: vpnProtocol)
        }

        // Skip the loop if there are no overrides.
        guard protocolEntries?.isEmpty == false else {
            return true
        }

        for vpnProtocol in smartProtocolConfig.supportedProtocols {
            if supports(vpnProtocol: vpnProtocol) {
                return true
            }
        }
        return false
    }

    public func overridePorts(using vpnProtocol: VpnProtocol) -> [Int]? {
        protocolEntries?[vpnProtocol]??.ports
    }

    /// Used for testing purposes.
    public var asDict: [String: Any] {
        var result: [String: Any] = [
            "ID": id,
            "ExitIP": exitIp,
            "Domain": domain,
            "Status": status,
        ]

        if let x25519PublicKey {
            result["X25519PublicKey"] = x25519PublicKey
        }
        if let label {
            result["Label"] = label
        }
        if let entryIp {
            result["EntryIP"] = entryIp
        }
        if let protocolEntries {
            result["EntryPerProtocol"] = protocolEntries.reduce(into: [:], { partialResult, keyPair in
                guard let key = VpnProtocol.protocolsToApiDescriptions[keyPair.key] else { return }
                partialResult[key] = keyPair.value?.asDict
            })
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
        case protocolEntries = "entryPerProtocol"
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
        let protocolEntries = aDecoder.decodeObject(forKey: CoderKey.protocolEntries.rawValue) as? [VpnProtocol: ProtocolEntry]

        self.init(id: id,
                  entryIp: entryIp,
                  exitIp: exitIp,
                  domain: domain,
                  status: status,
                  label: label,
                  x25519PublicKey: x25519PublicKey,
                  protocolEntries: protocolEntries)
    }
    
    public func encode(with aCoder: NSCoder) {
        aCoder.encode(id, forKey: CoderKey.ID.rawValue)
        aCoder.encode(entryIp, forKey: CoderKey.entryIp.rawValue)
        aCoder.encode(exitIp, forKey: CoderKey.exitIp.rawValue)
        aCoder.encode(domain, forKey: CoderKey.domain.rawValue)
        aCoder.encode(status, forKey: CoderKey.status.rawValue)
        aCoder.encode(label, forKey: CoderKey.label.rawValue)
        aCoder.encode(x25519PublicKey, forKey: CoderKey.x25519PublicKey.rawValue)
        aCoder.encode(protocolEntries, forKey: CoderKey.protocolEntries.rawValue)
    }
    
    public var underMaintenance: Bool {
        return status == 0
    }

    // MARK: - Static functions
    
    // swiftlint:disable:next nsobject_prefer_isequal
    public static func == (lhs: ServerIp, rhs: ServerIp) -> Bool {
        return lhs.domain == rhs.domain
    }

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
        let protocolEntries = try container.decodeIfPresent([VpnProtocol: ProtocolEntry].self,
                                                            forKey: .protocolEntries)
        
        self.init(id: id,
                  entryIp: entryIp,
                  exitIp: exitIp,
                  domain: domain,
                  status: status,
                  label: label,
                  x25519PublicKey: x25519PublicKey,
                  protocolEntries: protocolEntries)
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
        try container.encode(protocolEntries, forKey: .protocolEntries)
    }
}

extension ServerIp.ProtocolEntry {
    public init(dic: JSONDictionary) throws {
        self.ipv4 = dic.string("IPv4")
        self.ports = dic.intArray(key: "Ports")
    }

    public var asDict: JSONDictionary {
        var result: JSONDictionary = [:]
        if let ipv4 {
            result["IPv4"] = ipv4 as AnyObject
        }

        if let ports {
            result["Ports"] = ports as AnyObject
        }

        return result
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
