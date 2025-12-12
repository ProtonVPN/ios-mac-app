//
//  Created on 05/12/2023.
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

import Dependencies
import GRDB

import Domain
import Ergonomics

public extension ServerRepository {
    static var liveValue: ServerRepository {
        @Dependency(\.databaseConfiguration) var config

        let dbWriter = DatabaseQueue.from(databaseConfiguration: config)
        let executor = config.executor

        return ServerRepository(
            serverCount: {
                executor.read(dbWriter: dbWriter) { db in
                    try Logical.fetchCount(db)
                }
            },
            countryCount: {
                executor.read(dbWriter: dbWriter) { db in
                    try Logical
                        .select(Logical.Columns.exitCountryCode).distinct()
                        .fetchCount(db)
                }
            },
            upsertServers: { vpnServers in
                executor.write(dbWriter: dbWriter) { db in
                    try vpnServers.forEach { vpnServer in
                        try vpnServer.logicalRecord.insert(db, onConflict: .replace)
                        try vpnServer.logicalStatus.insert(db, onConflict: .replace)
                        try vpnServer.endpointRecords.forEach { endpoint in
                            try endpoint.insert(db, onConflict: .replace)
                        }
                        try vpnServer.overrideRecords.forEach { overridesInfo in
                            try overridesInfo.insert(db, onConflict: .replace)
                        }
                    }
                }
            },
            server: { filters, order in
                executor.read(dbWriter: dbWriter) { db in
                    let request = ServerResult.request(filters: filters, order: order)
                    let result = try ServerResult.fetchOne(db, request)

                    guard let result else { return nil }

                    return Domain.VPNServer(
                        logical: Domain.Logical(
                            staticInfo: result.logical,
                            dynamicInfo: result.logicalStatus
                        ),
                        endpoints: result.endpoints.map {
                            Domain.ServerEndpoint(
                                server: $0.server,
                                overrides: $0.overrideInfo
                            )
                        }
                    )
                }
            },
            servers: { filters, order in
                executor.read(dbWriter: dbWriter) { db in
                    let request = ServerInfoResult.request(filters: filters, order: order)

                    let results = try ServerInfoResult.fetchAll(db, request)
                    return results.map {
                        Domain.ServerInfo(
                            logical: Domain.Logical(
                                staticInfo: $0.logical,
                                dynamicInfo: $0.logicalStatus
                            ),
                            protocolSupport: $0.protocolMask
                        )
                    }
                }
            },
            deleteServers: { ids, maxTier in
                executor.write(dbWriter: dbWriter) { db in
                    try Logical
                        .filter(!ids.contains(Logical.Columns.id))
                        .filter(Logical.Columns.tier <= maxTier)
                        .deleteAll(db)
                }
            },
            upsertLoads: { loads in
                executor.write(dbWriter: dbWriter) { db in
                    let statusAlias = TableAlias()
                    let request = Logical
                        .joining(required: Logical.status.aliased(statusAlias))
                        .select(Logical.Columns.id, statusAlias[LogicalStatus.Columns.status])
                    let rows = try Row.fetchSet(db, request)
                    let logicalStatusMap: [String: Int] = rows.reduce(into: [:]) { dict, row in
                        dict[row[Logical.Columns.id]] = row[LogicalStatus.Columns.status]
                    }
                    // Do not update loads for servers that are coming out of maintenance
                    // This is because we don't know which server endpoint to update along with the logical status
                    let loadsToUpsert = loads.filter {
                        guard let currentStatus = logicalStatusMap[$0.serverId] else {
                            // There is no logical with this id in our DB, skip it
                            return false
                        }
                        if currentStatus == 0, $0.status != 0 {
                            // This logical is coming out of maintenance, skip it
                            return false
                        }
                        return true
                    }
                    try loadsToUpsert
                        .forEach { try $0.databaseRecord.insert(db, onConflict: .replace) }
                }
            },
            groups: { filters, grouping, order in
                executor.read(dbWriter: dbWriter) { db in
                    let request = GroupInfoResult.request(filters: filters, grouping: grouping, groupOrder: order)

                    let groups = try GroupInfoResult.fetchAll(db, request).map(\.domainModel)
                    return Dictionary(grouping: groups.filter {
                        if case .gateway = $0.kind { return true }
                        return false
                    }, by: \.kind)
                        .compactMap { key, values in
                            guard let first = values.first else { return nil }
                            let isUnderMaintenance: Bool = values.allSatisfy(\.isUnderMaintenance)
                            return .init(
                                kind: key,
                                featureIntersection: first.featureIntersection,
                                featureUnion: first.featureUnion,
                                minTier: first.minTier,
                                maxTier: first.maxTier,
                                serverCount: values.count, // Passing correct serverCount in the group
                                cityCount: 1,
                                latitude: first.latitude,
                                longitude: first.longitude,
                                supportsSmartRouting: first.supportsSmartRouting,
                                isUnderMaintenance: isUnderMaintenance,
                                protocolSupport: first.protocolSupport
                            )
                        } // We group gateways by gateway name.
                        .sorted {
                            if case let (.gateway(name1), .gateway(name2)) = ($0.kind, $1.kind) {
                                return name1 < name2
                            }
                            return false
                        } // Sorting gateways by gateway name.
                        + groups.filter {
                            if case .gateway = $0.kind { return false }
                            return true
                        } // Then adding all other kinds.
                }
            },
            getMetadata: { key in
                executor.read(dbWriter: dbWriter) { db in
                    let request = DatabaseMetadata
                        .select(DatabaseMetadata.columns.value)
                        .filter(DatabaseMetadata.columns.key == key.rawValue)

                    return try String.fetchOne(db, request)
                }
            },
            setMetadata: { key, value in
                executor.write(dbWriter: dbWriter) { db in
                    guard let value else {
                        try DatabaseMetadata
                            .filter(DatabaseMetadata.columns.key == key.rawValue)
                            .deleteAll(db)
                        return
                    }
                    try DatabaseMetadata(key: key, value: value).insert(db, onConflict: .replace)
                }
            },
            closeConnection: { try dbWriter.close() }
        )
    }
}
