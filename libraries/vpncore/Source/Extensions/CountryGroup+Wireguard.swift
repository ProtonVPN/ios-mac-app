//
//  CountryGroup+Wireguard.swift
//  ProtonVPN - Created on 2020-10-21.
//
//  Copyright (c) 2021 Proton Technologies AG
//
//  This file is part of ProtonVPN.
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
//

import Foundation

extension Array where Element == CountryGroup {
    public func filter(onlyWireguardServersAndCountries: Bool) -> Self {
        guard onlyWireguardServersAndCountries else {
            return self
        }

        var result: [CountryGroup] = []

        for (country, servers) in self {
            var wireguardServers: [ServerModel] = []

            for server in servers {
                let wireguardIps = server.ips.filter({ $0.supportsWireguard })

                if !wireguardIps.isEmpty {
                    wireguardServers.append(ServerModel(id: server.id, name: server.name, domain: server.domain, load: server.load, entryCountryCode: server.entryCountryCode, exitCountryCode: server.exitCountryCode, tier: server.tier, feature: server.feature, city: server.city, ips: wireguardIps, score: server.score, status: server.status, location: server.location, hostCountry: server.hostCountry))
                }
            }

            if !wireguardServers.isEmpty {
                result.append((country, wireguardServers))
            }
        }

        return result
    }
}
