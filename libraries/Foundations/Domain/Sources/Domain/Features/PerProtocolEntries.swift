//
//  Created on 11.01.23.
//
//  Copyright (c) 2023 Proton AG
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

/// API overrides for connection parameters when using a certain protocol.
///
/// Given an entry `e` exists for a protocol `p` on `ServerIp` object `s`:
/// 1. If `e.ipv4` is `nil`, `s` only supports `p`, and must use `s.entryIp` when connecting.
/// 2. If `e.ipv4` is not `nil`, `s` supports all protocols. Client must use `e.ipv4` when connecting with `p`.
/// 3. If `e.ports` is non-empty, client must choose from these ports when connecting, instead of ports from config.
public struct PerProtocolEntries: Equatable, RawRepresentable, ExpressibleByDictionaryLiteral, Codable, Sendable {
    public let rawValue: [String : Value]

    public init(rawValue: [String : Value]) {
        self.rawValue = rawValue
    }

    public init(dictionaryLiteral elements: (Key, Value)...) {
        self.rawValue = .init(elements.map { ($0.0.apiDescription, $0.1) },
                              uniquingKeysWith: { l, r in l })
    }

    public subscript(_ vpnProtocol: VpnProtocol) -> Value? {
        self.rawValue[vpnProtocol.apiDescription]
    }

    public var isEmpty: Bool {
        rawValue.isEmpty
    }

    public typealias Key = VpnProtocol
    public typealias Value = ServerProtocolEntry?

    public init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        self.rawValue = try container.decode([String : PerProtocolEntries.Value].self)
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        try container.encode(self.rawValue)
    }
}

extension PerProtocolEntries: CustomStringConvertible {
    public var description: String {
        // ", with overrides for:\n"
        rawValue.map {
            "\t\($0.key) => \($0.value?.description ?? "(nil)")\n"
        }.reduce("", +)
    }
}

extension PerProtocolEntries {
    /// Determine the appropriate entry IP to use for the given `ServerIp` object and
    /// protocol, according to the `entryIp` and `rawValue` properties.
    /// - Warning: The `entryIp` property is nullable, be careful when changing this function.
    public func overrides(vpnProtocol: VpnProtocol, defaultIp: String?) -> String? {
        // Check to see if the given server IP contains a per-protocol override.
        guard let override = self[vpnProtocol] else {
            // An override does not exist on the server IP for the current protocol.
            // If the server IP contains an override where an IP address is nil, then it means that this server IP only
            // supports protocols for which there is an entry in the overrides list. Thus, if this guard fails, then on
            // this server IP there is no entry IP that supports `vpnProtocol`.
            guard !rawValue.contains(where: { $0.value?.ipv4 == nil }) else {
                return nil
            }

            // An override doesn't exist, and no overrides are present that have a null entry IP.
            // This is the default case, return the normal entry IP.
            return defaultIp
        }

        // An override for the given protocol exists, but doesn't define an IP address. This means
        // that the ServerIp in question supports this protocol, but should connect with `entryIp`.
        guard let ip = override?.ipv4 else {
            return defaultIp
        }

        // An override for the given protocol exists, and the IP address is defined. Return this
        // overridden IP address.
        return ip
    }
    
    public func overridePorts(using vpnProtocol: VpnProtocol) -> [Int]? {
        self[vpnProtocol]??.ports
    }
}

public struct ServerProtocolEntry: Equatable, Codable, Sendable {
    public let ipv4: String?
    public let ports: [Int]?

    enum CodingKeys: String, CodingKey {
        case ipv4 = "IPv4"
        case ports
    }

    public init(ipv4: String?, ports: [Int]?) {
        self.ipv4 = ipv4
        self.ports = ports
    }
}

extension ServerProtocolEntry: CustomStringConvertible {
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
