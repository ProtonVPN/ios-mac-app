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

import Domain

extension VPNServer {

    /// Instantiates a domain model from legacy model (DTO)
    public init(legacyModel: ServerModel) {
        self.init(
            logical: Logical(
                id: legacyModel.id,
                name: legacyModel.name,
                domain: legacyModel.domain,
                load: legacyModel.load,
                entryCountryCode: legacyModel.entryCountryCode,
                exitCountryCode: legacyModel.exitCountryCode,
                tier: legacyModel.tier,
                score: legacyModel.score,
                status: legacyModel.status,
                feature: legacyModel.feature,
                city: legacyModel.city,
                hostCountry: legacyModel.hostCountry,
                translatedCity: legacyModel.translatedCity,
                latitude: legacyModel.location.lat,
                longitude: legacyModel.location.long,
                gatewayName: legacyModel.gatewayName
            ),
            endpoints: legacyModel.ips.map { ServerEndpoint(legacyModel: $0) }
        )
    }

}

extension ServerModel {

    /// Instantiates a legacy model (DTO) object from a domain model
    convenience init(logical: Domain.Logical, endpoints: [Domain.ServerEndpoint]) {
        self.init(
            id: logical.id,
            name: logical.name,
            domain: logical.domain,
            load: logical.load,
            entryCountryCode: logical.entryCountryCode,
            exitCountryCode: logical.exitCountryCode,
            tier: logical.tier,
            feature: logical.feature,
            city: logical.city,
            ips: endpoints.map { ServerIp(endpoint: $0)},
            score: logical.score,
            status: logical.status,
            location: .init(lat: logical.latitude, long: logical.longitude),
            hostCountry: logical.hostCountry,
            translatedCity: logical.translatedCity,
            gatewayName: logical.gatewayName
        )
    }

    /// Instantiates a legacy model (DTO) object from a domain model
    public convenience init(server: Domain.VPNServer) {
        self.init(logical: server.logical, endpoints: server.endpoints)
    }
}


extension Domain.ServerEndpoint {

    /// Instantiates a legacy model (DTO) object from a domain model
    init(legacyModel: ServerIp) {
        self.init(
            id: legacyModel.id,
            entryIp: legacyModel.entryIp,
            exitIp: legacyModel.exitIp,
            domain: legacyModel.domain,
            status: legacyModel.status,
            label: legacyModel.label,
            x25519PublicKey: legacyModel.x25519PublicKey,
            protocolEntries: legacyModel.protocolEntries
        )
    }
}

extension ServerIp {

    /// Instantiates a legacy model (DTO) object from a domain model
    convenience init(endpoint: Domain.ServerEndpoint) {
        self.init(
            id: endpoint.id,
            entryIp: endpoint.entryIp,
            exitIp: endpoint.exitIp,
            domain: endpoint.domain,
            status: endpoint.status,
            label: endpoint.label,
            x25519PublicKey: endpoint.x25519PublicKey,
            protocolEntries: endpoint.protocolEntries
        )
    }
}
