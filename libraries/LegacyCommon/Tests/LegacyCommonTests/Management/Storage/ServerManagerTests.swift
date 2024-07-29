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

import ProtonCoreFeatureFlags

import Domain
import Persistence
import PersistenceTestSupport
@testable import LegacyCommon

final class ServerManagerTests: XCTestCase {

    private var upsertCallback: (([VPNServer]) -> Void)?
    private var deleteCallback: ((Set<String>, Int) -> Void)?
    private var metadataCallback: ((DatabaseMetadata.Key, String?) -> Void)?

    class override func setUp() {
        super.setUp()
        FeatureFlagsRepository.shared.setFlagOverride(VPNFeatureFlagType.timestampedLogicals, true)
    }

    class override func tearDown() {
        super.tearDown()
        FeatureFlagsRepository.shared.resetFlagOverride(VPNFeatureFlagType.timestampedLogicals)
    }

    private func performServerUpdate(servers: [VPNServer], freeServersOnly: Bool, lastModifiedAt: String?) {
        withDependencies {
            $0.serverRepository = .init(
                upsertServers: { [weak self] servers in self?.upsertCallback?(servers) },
                deleteServers: { [weak self] ids, maxTier in
                    self?.deleteCallback?(ids, maxTier)
                    return -1
                },
                setMetadata: { [weak self] key, value in self?.metadataCallback?(key, value) }
            )
        } operation: {
            ServerManager.liveValue.update(servers: servers, freeServersOnly: freeServersOnly, lastModifiedAt: lastModifiedAt)
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

        performServerUpdate(servers: servers, freeServersOnly: true, lastModifiedAt: nil)

        wait(for: [deleteInvoked, upsertInvoked], timeout: 1.0)
    }

    func testPurgesAllTiersWhenFetchingFullServerList() {
        let deleteInvoked = XCTestExpectation()

        deleteCallback = { ids, maxTier in
            XCTAssertGreaterThanOrEqual(maxTier, .internalTier)
            deleteInvoked.fulfill()
        }

        performServerUpdate(servers: [], freeServersOnly: false, lastModifiedAt: nil)

        wait(for: [deleteInvoked], timeout: 1.0)
    }

    func testUpdatesLastModifiedValueWhenNotNil() {
        let lastModified = "A few moments ago"
        let metadataExpectation = XCTestExpectation(description: "Expected last modified metadata to be updated")
        metadataExpectation.expectedFulfillmentCount = 1

        self.metadataCallback = { key, value in
            XCTAssertEqual(key, .lastModifiedFree)
            XCTAssertEqual(value, lastModified)
            metadataExpectation.fulfill()
        }

        performServerUpdate(servers: [], freeServersOnly: true, lastModifiedAt: lastModified)

        wait(for: [metadataExpectation], timeout: 1.0)
    }

    func testDoesNotOverwriteLastModifiedValueWhenNil() {
        self.metadataCallback = { _, _ in XCTFail("Metadata should not be cleared when the new last modified value is nil") }

        performServerUpdate(servers: [], freeServersOnly: true, lastModifiedAt: nil)
    }
}
