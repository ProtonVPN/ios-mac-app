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

import Domain
import GRDB
@testable import Persistence
import Testing

@Suite("Endpoint protocol mask migration")
struct EndpointProtocolMaskMigrationTests {
    /// Rows as they looked at v3: no mask on `endpoint`, and one on `endpointOverrides` for the endpoints
    /// that had per-protocol entries.
    private func databaseAtV3() throws -> DatabaseQueue {
        let queue = try DatabaseQueue()
        try queue.write { db in
            for version in [SchemaVersion.v1, .v2, .v3] {
                try version.migrationBlock(db)
            }
            try db.execute(
                sql: """
                INSERT INTO logical (id, name, namePrefix, domain, exitCountryCode, tier, feature, latitude, longitude)
                VALUES ('logical', 'CH#1', 'CH#', 'a', 'CH', 0, 0, 0, 0)
                """
            )
            try db.execute(
                sql: """
                INSERT INTO endpoint (id, logicalId, entryIP, exitIP, domain, status) VALUES
                    ('with-address', 'logical', '1.2.3.4', '1.2.3.5', 'a', 1),
                    ('without-address', 'logical', NULL, '1.2.3.6', 'a', 1),
                    ('with-entries', 'logical', NULL, '1.2.3.7', 'a', 1)
                """
            )
            try db.execute(
                sql: """
                INSERT INTO endpointOverrides (endpointId, protocolMask, protocolEntries)
                VALUES ('with-entries', \(ProtocolSupport.wireGuardTLS.rawValue), '{"WireGuardTLS":{"IPv4":"1.2.3.8"}}')
                """
            )
        }
        return queue
    }

    private func migratedDatabase() throws -> DatabaseQueue {
        let queue = try databaseAtV3()
        try queue.write { try SchemaVersion.v4.migrationBlock($0) }
        return queue
    }

    private func mask(of endpointId: String, in queue: DatabaseQueue) throws -> Int? {
        try queue.read { db in
            try Int.fetchOne(db, sql: "SELECT protocolMask FROM endpoint WHERE id = ?", arguments: [endpointId])
        }
    }

    @Test("Carries over the mask an overrides row already held")
    func carriesOverTheMaskAnOverridesRowAlreadyHeld() throws {
        let queue = try migratedDatabase()

        #expect(try mask(of: "with-entries", in: queue) == ProtocolSupport.wireGuardTLS.rawValue)
    }

    @Test("Gives endpoints reached through a default address every protocol")
    func givesEndpointsWithADefaultAddressEveryProtocol() throws {
        let queue = try migratedDatabase()

        #expect(try mask(of: "with-address", in: queue) == ProtocolSupport.all.rawValue)
    }

    /// The reason for the migration. Without an address there is nothing to connect to, so the endpoint
    /// must not come out of it claiming to support every protocol.
    @Test("Gives endpoints without any address no protocols")
    func givesEndpointsWithoutAnyAddressNoProtocols() throws {
        let queue = try migratedDatabase()

        #expect(try mask(of: "without-address", in: queue) == ProtocolSupport.zero.rawValue)
    }

    @Test("Drops the mask from the overrides table but keeps the entries")
    func dropsTheMaskFromTheOverridesTableButKeepsTheEntries() throws {
        let queue = try migratedDatabase()

        try queue.read { db in
            let columns = try db.columns(in: "endpointOverrides").map(\.name)
            #expect(!columns.contains("protocolMask"))
            #expect(columns.contains("protocolEntries"))
            #expect(try Int.fetchOne(db, sql: "SELECT COUNT(*) FROM endpointOverrides") == 1)
        }
    }
}
