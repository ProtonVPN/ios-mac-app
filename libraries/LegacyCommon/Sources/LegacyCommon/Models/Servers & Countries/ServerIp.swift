//
//  ServerIp.swift
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
import VPNShared
import VPNAppCore

public class ServerIp: NSObject, NSCoding, Codable {
    public let id: String // "ID": "l8vWAXHBQNSQjPrxAr-D_BCxj1X0nW70HQRmAa-rIvzmKUA=="
    public let entryIp: String? // "EntryIP": "95.215.61.163"
    public let exitIp: String // "ExitIP": "95.215.61.164"
    public let domain: String  // "Domain": "es-04.protonvpn.com"
    public let status: Int // "Status": 1  (1 - OK, 0 - under maintenance)
    public let label: String?
    public let x25519PublicKey: String?
    public let protocolEntries: PerProtocolEntries?
    
    override public var description: String {
        let entryOverrides = protocolEntries?.description.prepending(", with overrides for:\n") ?? "\n"

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
                protocolEntries: PerProtocolEntries? = nil) {
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
        self.protocolEntries = PerProtocolEntries(dic: dic)
        super.init()
    }

    public func entryIp(using vpnProtocol: VpnProtocol) -> String? {
        guard let protocolEntries else {
            return entryIp
        }

        return protocolEntries.overrides(vpnProtocol: vpnProtocol, defaultIp: entryIp)
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
        guard protocolEntries?.isEmpty != true else {
            return true
        }

        for vpnProtocol in smartProtocolConfig.supportedProtocols {
            if supports(vpnProtocol: vpnProtocol) {
                return true
            }
        }
        return false
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
            result["EntryPerProtocol"] = protocolEntries.asDict
        }

        return result
    }
    
    // MARK: - NSCoding
    private enum CodingKeys: String, CodingKey {
        case id = "IDKey"
        case entryIp = "entryIpKey"
        case exitIp = "exitIpKey"
        case domain = "domainKey"
        case status = "statusKey"
        case label = "labelKey"
        case x25519PublicKey = "x25519PublicKey"
        case protocolEntries = "entryPerProtocol"
    }
    
    public required convenience init?(coder aDecoder: NSCoder) {
        guard let id = aDecoder.decodeObject(forKey: CodingKeys.id.rawValue) as? String,
            let entryIp = aDecoder.decodeObject(forKey: CodingKeys.entryIp.rawValue) as? String,
            let exitIp = aDecoder.decodeObject(forKey: CodingKeys.exitIp.rawValue) as? String,
            let domain = aDecoder.decodeObject(forKey: CodingKeys.domain.rawValue) as? String else {
                return nil
        }
        let status = aDecoder.decodeInteger(forKey: CodingKeys.status.rawValue)
        let label = aDecoder.decodeObject(forKey: CodingKeys.label.rawValue) as? String
        let x25519PublicKey = aDecoder.decodeObject(forKey: CodingKeys.x25519PublicKey.rawValue) as? String
        let protocolEntries = aDecoder.decodeObject(forKey: CodingKeys.protocolEntries.rawValue) as? PerProtocolEntries

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
        log.assertionFailure("We migrated away from NSCoding, this method shouldn't be used anymore")
    }
    
    public var underMaintenance: Bool {
        return status == 0
    }

    // MARK: - Static functions
    
    // swiftlint:disable:next nsobject_prefer_isequal
    public static func == (lhs: ServerIp, rhs: ServerIp) -> Bool {
        return lhs.domain == rhs.domain
    }
}

extension PerProtocolEntries {
    // looks like:
    // "EntryPerProtocol": {
    //     "WireGuardTLS": {"IPv4": "5.6.7.8"},
    //     "OpenVPNTCP": {"Ports": [22, 23]}
    //  }
    public init?(dic: JSONDictionary) {
        guard let entries = dic["EntryPerProtocol"] as? [String: JSONDictionary] else {
            return nil
        }

        self = .init(rawValue: entries.mapValues(ServerProtocolEntry.init(dic:)))
    }

    public var asDict: JSONDictionary {
        rawValue.reduce(into: [:]) { partialResult, keyPair in
            partialResult[keyPair.key] = keyPair.value?.asDict as? AnyObject
        }
    }
}

extension ServerProtocolEntry {
    public init?(dic: JSONDictionary) {
        self.init(ipv4: dic.string("IPv4"), ports: dic.intArray(key: "Ports"))
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
