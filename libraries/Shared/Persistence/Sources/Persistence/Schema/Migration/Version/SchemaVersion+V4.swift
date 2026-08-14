//
//  Created on 14/08/2026 by Max Kupetskyi.
//
//  Copyright (c) 2026 Proton AG
//
//  Proton VPN is free software: you can redistribute it and/or modify
//  it under the terms of the GNU General Public License as published by
//  the Free Software Foundation, either version 3 of the License, or
//  (at your option) any later version.
//
//  Proton VPN is distributed in the hope that it will be useful,
//  but WITHOUT ANY WARRANTY; without even the implied warranty of
//  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
//  GNU General Public License for more details.
//
//  You should have received a copy of the GNU General Public License
//  along with Proton VPN.  If not, see <https://www.gnu.org/licenses/>.

import Foundation
import GRDB

public extension SchemaVersion {
    /// Moves the protocol support mask from `endpointOverrides` onto `endpoint`.
    ///
    /// The mask records which protocols an endpoint actually has an address for.
    static let v4: SchemaVersion = {
        let migrationBlock: MigrationBlock = { db in
            try db.alter(table: "endpoint") { t in
                t.add(column: "protocolMask", .integer).notNull().defaults(to: 0)
            }

            // The mask an overrides row already holds was computed the same way, so carry it over.
            // Endpoints without one reach every protocol through their default entry IP, or nothing at
            // all when the API sent them without one. 15 is `ProtocolSupport.all` as of this migration
            try db.execute(
                sql: """
                UPDATE endpoint SET protocolMask = COALESCE(
                    (SELECT protocolMask FROM endpointOverrides WHERE endpointOverrides.endpointId = endpoint.id),
                    CASE WHEN entryIP IS NOT NULL THEN 15 ELSE 0 END
                )
                """
            )

            try db.alter(table: "endpointOverrides") { t in
                t.drop(column: "protocolMask")
            }
        }

        return SchemaVersion(identifier: "endpoint_protocol_mask", migrationBlock: migrationBlock)
    }()
}
