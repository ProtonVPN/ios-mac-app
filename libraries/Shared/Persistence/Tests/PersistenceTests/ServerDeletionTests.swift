//
//  Created on 27/01/2024.
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
import XCTest

import Dependencies

import Domain

@testable import Persistence

final class ServerDeletionTests: IsolatedDatabaseTestCase {

    func testDeleteStalePaidServers() throws {
        try Self.repository.upsert(
            servers: [
                mockServer(withID: "free1", tier: 0),
                mockServer(withID: "paid1", tier: 1),
                mockServer(withID: "stale1", tier: 1),
                mockServer(withID: "paid2", tier: 2),
                mockServer(withID: "free2", tier: 0),
                mockServer(withID: "stale2", tier: 2)
            ]
        )

        let deletedServerCount = try Self.repository.delete(
            serversWithMinTier: 1,
            withIDsNotIn: .init(arrayLiteral: "free1", "paid1", "paid2")
        )

        XCTAssertEqual(deletedServerCount, 2)

        let remainingServers = try Self.repository.getServers(filteredBy: [], orderedBy: .nameAscending)
        let remainingServerIDs = remainingServers.map { $0.logical.id }
        XCTAssertEqual(remainingServerIDs, ["free1", "free2", "paid1", "paid2"])
    }

    func mockServer(withID id: String, tier: Int) -> VPNServer {
        return VPNServer(
            logical: .init(
                id: id,
                name: id,
                domain: "a",
                load: 0,
                entryCountryCode: "CH",
                exitCountryCode: "CH",
                tier: tier,
                score: 0,
                status: 0,
                feature: .zero,
                city: nil,
                hostCountry: nil,
                translatedCity: nil,
                latitude: 0,
                longitude: 0,
                gatewayName: nil
            ),
            endpoints: [
                .init(
                    server: .init(
                        logicalId: id,
                        id: "endpoint\(id)",
                        entryIp: nil,
                        exitIp: "1",
                        domain: "a",
                        status: 0,
                        label: nil,
                        x25519PublicKey: ""
                    ),
                    overrides: nil
                )
            ]
        )
    }

}


