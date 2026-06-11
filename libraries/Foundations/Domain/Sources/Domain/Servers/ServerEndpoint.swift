//
//  Created on 11/12/2023.
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

public struct ServerEndpoint: Codable, Equatable, Identifiable, Sendable {
    public let id: String
    public let entryIp: String?
    public let exitIp: String
    public let domain: String
    public let status: Int
    public let label: String?
    public let x25519PublicKey: String?
    public let protocolEntries: PerProtocolEntries?

    public init(
        id: String,
        entryIp: String?,
        exitIp: String,
        domain: String,
        status: Int,
        label: String?,
        x25519PublicKey: String?,
        protocolEntries: PerProtocolEntries?
    ) {
        self.id = id
        self.entryIp = entryIp
        self.exitIp = exitIp
        self.domain = domain
        self.status = status
        self.label = label
        self.x25519PublicKey = x25519PublicKey
        self.protocolEntries = protocolEntries
    }

    public var isUnderMaintenance: Bool {
        status == 0
    }

    /// The actual exit IP is offset by the bouncing/label, if present.
    /// This value is plumbed through to local agent to distinguish between different physical exits.
    /// The offset e.g. `185.159.157.10` + label `5` -> `185.159.157.15`
    public var offsetExitIp: String {
        guard let label, let offset = Int(label) else {
            return exitIp
        }
        var octets = exitIp.split(separator: ".", omittingEmptySubsequences: false)
        guard octets.count == 4, let lastOctet = Int(octets[3]) else {
            return exitIp
        }
        octets[3] = Substring(String(lastOctet + offset))
        return octets.joined(separator: ".")
    }
}

typealias ProtocolOverrides = [VpnProtocol: ServerProtocolEntry]

// VPNAPPL-2099 This connection/business logic should probably live in a shared package in a layer above Domain.
public extension ServerEndpoint {
    func supports(vpnProtocol: VpnProtocol) -> Bool {
        entryIp(using: vpnProtocol) != nil
    }

    func entryIp(using vpnProtocol: VpnProtocol) -> String? {
        guard let protocolEntries else {
            return entryIp
        }

        return protocolEntries.overrides(vpnProtocol: vpnProtocol, defaultIp: entryIp)
    }

    func overridePorts(using vpnProtocol: VpnProtocol) -> [Int]? {
        guard let protocolEntries else {
            return nil
        }

        return protocolEntries[vpnProtocol]??.ports
    }

    /// Returns true if any of the protocols in the set are supported by this server ip.
    func supports(protocolSet: ProtocolSupport) -> Bool {
        !supportedProtocols.isDisjoint(with: protocolSet)
    }

    var supportedProtocols: ProtocolSupport {
        if protocolEntries == nil {
            return .all
        }

        return VpnProtocol.allCases.reduce(into: .zero) {
            if supports(vpnProtocol: $1) {
                $0.insert($1.protocolSupport)
            }
        }
    }
}
