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

import ProtonCoreUtilities

public struct ServerEndpoint: Codable, Equatable, Identifiable {
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
        entryIp: String? = nil,
        exitIp: String,
        domain: String,
        status: Int,
        label: String? = nil,
        x25519PublicKey: String? = nil,
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
}

typealias ProtocolOverrides = [VpnProtocol: ServerProtocolEntry]


/// This connection/business logic should probably live in a shared package in a layer above Domain.
/// Another advantage would be faster compilation of Domain since it would no longer depend on protoncore
extension ServerEndpoint {

    public func supports(vpnProtocol: VpnProtocol) -> Bool {
        entryIp(using: vpnProtocol) != nil
    }
    
    public func entryIp(using vpnProtocol: VpnProtocol) -> String? {
        guard let protocolEntries else {
            return entryIp
        }

        return protocolEntries.overrides(vpnProtocol: vpnProtocol, defaultIp: entryIp)
    }

    /// Returns true if any of the protocols in the set are supported by this server ip.
    public func supports(protocolSet: ProtocolSupport) -> Bool {
        return !supportedProtocols.isDisjoint(with: protocolSet)
    }

    public var supportedProtocols: ProtocolSupport {
        if self.protocolEntries == nil {
            return .all
        }

        let support: ProtocolSupport = []
            .appending(.ikev2, if: supports(vpnProtocol: .ike))
            .appending(.wireGuardUDP, if: supports(vpnProtocol: .wireGuard(.udp)))
            .appending(.wireGuardTCP, if: supports(vpnProtocol: .wireGuard(.tcp)))
            .appending(.wireGuardTLS, if: supports(vpnProtocol: .wireGuard(.tls)))
            .reduce(.zero) { $0.union($1) }
        return support
    }
}
