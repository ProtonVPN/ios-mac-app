//
//  Created on 09/04/2024.
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

import XCTest

import Dependencies

import Domain
import PersistenceTestSupport
@testable import LegacyCommon

final class ServerManagerTests: XCTestCase {

    private var upsertCallback: (([VPNServer]) -> Void)?
    private var deleteCallback: ((Set<String>, Int) -> Void)?

    private func testServerUpdate(servers: [VPNServer], freeServersOnly: Bool) {
        withDependencies {
            $0.serverRepository = .init(
                upsertServers: { servers in self.upsertCallback?(servers) },
                deleteServers: { ids, maxTier in
                    self.deleteCallback?(ids, maxTier)
                    return -1
                }
            )
        } operation: {
            ServerManager.liveValue.update(servers: servers, freeServersOnly: freeServersOnly)
        }
    }

    func testKeepsHigherTierStaleServerWhenFetchingPartialServerList() {
        let servers = [TestData.createMockServer(withID: "a"), TestData.createMockServer(withID: "b")]

        let deleteInvoked = XCTestExpectation()
        let upsertInvoked = XCTestExpectation()

        deleteCallback = { ids, maxTier in
            XCTAssertEqual(ids, Set(arrayLiteral: "a", "b"))
            XCTAssertEqual(maxTier, .freeTier)
            deleteInvoked.fulfill()
        }

        upsertCallback = { servers in
            XCTAssertEqual(servers, servers)
            upsertInvoked.fulfill()
        }

        testServerUpdate(servers: servers, freeServersOnly: true)

        wait(for: [deleteInvoked, upsertInvoked], timeout: 1.0)
    }

    func testPurgesAllTiersWhenFetchingFullServerList() {
        let deleteInvoked = XCTestExpectation()

        deleteCallback = { ids, maxTier in
            XCTAssertGreaterThanOrEqual(maxTier, .internalTier)
            deleteInvoked.fulfill()
        }

        testServerUpdate(servers: [], freeServersOnly: false)

        wait(for: [deleteInvoked], timeout: 1.0)
    }
}
