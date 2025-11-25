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
@testable import LegacyCommon
import Persistence
import PersistenceTestSupport

final class ServerManagerTests: XCTestCase {
    private var upsertCallback: (([VPNServer]) -> Void)?
    private var deleteCallback: ((Set<String>, Int) -> Void)?
    private var metadataCallback: ((DatabaseMetadata.Key, String?) -> Void)?
    private var metadata: ((DatabaseMetadata.Key) -> String?)?

    private var repository: ServerRepository!

    override class func setUp() {
        super.setUp()
        FeatureFlagsRepository.shared.setFlagOverride(VPNFeatureFlagType.timestampedLogicals, true)
    }

    override class func tearDown() {
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
                getMetadata: { [weak self] key in self?.metadata?(key) },
                setMetadata: { [weak self] key, value in self?.metadataCallback?(key, value) }
            )
        } operation: {
            ServerManager.liveValue.update(servers: servers, freeServersOnly: freeServersOnly, lastModifiedAt: lastModifiedAt)
        }
    }

    private func setMetadata(to dictionary: [DatabaseMetadata.Key: String?]) {
        metadata = { key in dictionary[key].flatMap { $0 } }
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

        deleteCallback = { _, maxTier in
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

        metadataCallback = { key, value in
            if key == .lastModifiedFree {
                XCTAssertEqual(value, lastModified)
                metadataExpectation.fulfill()
            }
        }

        performServerUpdate(servers: [], freeServersOnly: true, lastModifiedAt: lastModified)

        wait(for: [metadataExpectation], timeout: 1.0)
    }

    func testDoesNotOverwriteLastModifiedValueWhenNil() {
        metadataCallback = { key, _ in
            // Last modified metadata should not be updated when the new last modified value is nil
            XCTAssertNotEqual(key, .lastModifiedFree)
            XCTAssertNotEqual(key, .lastModifiedAll)
            XCTAssertEqual(key, .consecutiveSuccessfulRefreshes)
        }

        performServerUpdate(servers: [], freeServersOnly: true, lastModifiedAt: nil)
    }

    func incrementsSuccessfulRefreshesAfterUpdatingLogicals() {
        // Set existing value in DB
        setMetadata(to: [.consecutiveSuccessfulRefreshes: "5"])

        let metadataUpdated = XCTestExpectation(description: "Successful refreshes should have been updated")
        metadataCallback = { key, value in
            // As we upsert servers into the database, we should increment the value
            XCTAssertEqual(key, .consecutiveSuccessfulRefreshes)
            XCTAssertEqual(value, "6")
            metadataUpdated.fulfill()
        }

        performServerUpdate(servers: [], freeServersOnly: true, lastModifiedAt: nil)
        wait(for: [metadataUpdated], timeout: 0)
    }

    func successfulRefreshesResetsBeforeTen() {
        // Set existing value in DB
        setMetadata(to: [.consecutiveSuccessfulRefreshes: "9"])

        let metadataUpdated = XCTestExpectation(description: "Successful refreshes should have been updated")
        metadataCallback = { key, value in
            // As we upsert servers into the database, we should increment the value
            XCTAssertEqual(key, .consecutiveSuccessfulRefreshes)
            XCTAssertEqual(value, "0")
            metadataUpdated.fulfill()
        }

        performServerUpdate(servers: [], freeServersOnly: true, lastModifiedAt: nil)
        wait(for: [metadataUpdated], timeout: 0)
    }

    func requestsFullServerRefreshOnFirstFetch() {
        setMetadata(to: [.consecutiveSuccessfulRefreshes: nil])
        withDependencies {
            $0.serverRepository = .init(getMetadata: { [weak self] key in self?.metadata?(key) })
        } operation: {
            XCTAssertTrue(ServerManager.liveValue.shouldFetchFullServerList)
        }
    }

    func requestsFullServerListOnFirstFetch() {
        setMetadata(to: [.consecutiveSuccessfulRefreshes: nil])
        withDependencies {
            $0.serverRepository = .init(getMetadata: { [weak self] key in self?.metadata?(key) })
        } operation: {
            XCTAssertTrue(ServerManager.liveValue.shouldFetchFullServerList)
        }

        setMetadata(to: [.consecutiveSuccessfulRefreshes: "0"])
        withDependencies {
            $0.serverRepository = .init(getMetadata: { [weak self] key in self?.metadata?(key) })
        } operation: {
            XCTAssertTrue(ServerManager.liveValue.shouldFetchFullServerList)
        }
    }

    func requestsPartialServerList() {
        let consecutiveRefreshesToRequestPartialServerListWith = Array(1 ... 9)

        for value in consecutiveRefreshesToRequestPartialServerListWith {
            setMetadata(to: [.consecutiveSuccessfulRefreshes: "\(value)"])
            withDependencies {
                $0.serverRepository = .init(getMetadata: { [weak self] key in self?.metadata?(key) })
            } operation: {
                XCTAssertFalse(ServerManager.liveValue.shouldFetchFullServerList)
            }
        }
    }
}
