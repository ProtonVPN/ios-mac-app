//
//  Created on 18/03/2024.
//
//  Copyright (c) 2024 Proton AG
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

import GRDB

extension SchemaVersion {

    public static let v1: SchemaVersion = {
        let migrationBlock: MigrationBlock = { db in
            try db.create(table: "logical") { t in
                t.column("id", .text).notNull().primaryKey()
                t.column("name", .text).notNull()
                t.column("namePrefix", .text).notNull()
                t.column("sequenceNumber", .integer)
                t.column("domain", .text).notNull()
                t.column("entryCountryCode", .text)
                t.column("exitCountryCode", .text).notNull()
                t.column("tier", .integer).notNull()
                t.column("feature", .integer).notNull()
                t.column("latitude", .double).notNull()
                t.column("longitude", .double).notNull()
                t.column("city", .text)
                t.column("hostCountry", .text)
                t.column("translatedCity", .text)
                t.column("gatewayName", .text)
            }

            // Define indexes for fields we sort/filter/group by
            try db.create(indexOn: "logical", columns: ["namePrefix", "sequenceNumber"]) // sorting servers by name
            try db.create(indexOn: "logical", columns: ["gatewayName", "exitCountryCode"]) // grouping groups

            try db.create(table: "endpoint") { t in
                t.column("id", .text).notNull().primaryKey()
                t.column("entryIP", .text)
                t.column("exitIP", .text).notNull()
                t.column("domain", .text).notNull()
                t.column("status", .integer)
                t.column("label", .text)
                t.column("x25519PublicKey", .text)
                t.column("protocolEntries", .jsonText)
                t.belongsTo("logical", onDelete: .cascade).notNull() // foreign key (logicalID column)
            }

            try db.create(table: "logicalStatus") { t in
                t.column("score", .double).notNull()
                t.column("status", .integer).notNull()
                t.column("load", .integer).notNull()
                t.belongsTo("logical", onDelete: .cascade).notNull().unique() // foreign key (logicalID column)
            }

            // covering index for sorting by fastest server
            try db.create(indexOn: "logicalStatus", columns: ["status", "score", "load"])

            try db.create(table: "endpointOverrides") { t in
                t.column("protocolMask", .integer)
                t.column("protocolEntries", .text)
                t.belongsTo("endpoint", onDelete: .cascade).notNull().unique() // foreign key (endpointID column)
            }
        }

        return SchemaVersion(identifier: "initial schema", migrationBlock: migrationBlock)
    }()
}
