//
//  CountryGroup+Wireguard.swift
//  ProtonVPN
//
//  Created by Igor Kulman on 25.06.2021.
//  Copyright © 2021 Proton Technologies AG. All rights reserved.
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
                    wireguardServers.append(ServerModel(id: server.id, name: server.name, domain: server.domain, load: server.load, entryCountryCode: server.entryCountryCode, exitCountryCode: server.exitCountryCode, tier: server.tier, feature: server.feature, city: server.city, ips: wireguardIps, score: server.score, status: server.status, location: server.location))
                }
            }

            if !wireguardServers.isEmpty {
                result.append((country, wireguardServers))
            }
        }

        return result
    }
}
