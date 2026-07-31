//
//  Created on 30/07/2026 by Max Kupetskyi.
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

import Dependencies
import Domain
import Foundation
import Persistence
import PersistenceTestSupport
import Testing

@Suite("Server list refresh")
struct ServerListRefreshTests {
    /// Backed by a fresh in-memory database for each test, since Swift Testing instantiates the suite per test.
    private let repository: ServerRepository = withDependencies {
        $0.databaseConfiguration = .withTestExecutor(databaseType: .ephemeral(filePath: nil))
    } operation: {
        ServerRepositoryKey.liveValue
    }

    private func storedServerIDs() -> [String] {
        repository
            .getServers(filteredBy: [], orderedBy: .nameAscending)
            .map(\.logical.id)
    }

    // MARK: - Replacing the server list

    @Test("Keeps stale servers above the requested tier when replacing a partial server list")
    func keepsHigherTierStaleServers() {
        repository.upsert(
            servers: [
                TestData.createMockServer(withID: "free1", tier: 0),
                TestData.createMockServer(withID: "staleFree", tier: 0),
                TestData.createMockServer(withID: "paid1", tier: 2),
            ]
        )

        let purgedServerCount = repository.replace(
            servers: [
                TestData.createMockServer(withID: "free1", tier: 0),
                TestData.createMockServer(withID: "free2", tier: 0),
            ],
            maxTier: VpnTier.free.rawValue
        )

        // `staleFree` is purged, but `paid1` is above the requested tier so this response says nothing about it
        #expect(purgedServerCount == 1)
        #expect(storedServerIDs() == ["free1", "free2", "paid1"])
    }

    @Test("Purges every tier when replacing the full server list")
    func purgesAllTiersWhenReplacingFullServerList() {
        repository.upsert(
            servers: [
                TestData.createMockServer(withID: "free1", tier: 0),
                TestData.createMockServer(withID: "paid1", tier: 2),
                TestData.createMockServer(withID: "internal1", tier: 3),
            ]
        )

        let purgedServerCount = repository.replace(servers: [], maxTier: VpnTier.internal.rawValue)

        #expect(purgedServerCount == 3)
        #expect(repository.isEmpty)
    }

    // MARK: - Full server list refresh policy

    @Test("Fetches the full server list on the first refresh")
    func fetchesFullServerListOnFirstRefresh() {
        #expect(repository.getMetadata(.consecutiveSuccessfulRefreshes) == nil)
        #expect(repository.consecutiveSuccessfulRefreshes == 0)
        #expect(repository.shouldFetchFullServerList)
    }

    @Test("Counts consecutive refreshes, wrapping back to a full server list fetch")
    func countsConsecutiveRefreshes() {
        for expectedRefreshes in 1 ..< ServerRepository.fullServerListRefreshInterval {
            repository.recordSuccessfulRefresh()

            #expect(repository.consecutiveSuccessfulRefreshes == expectedRefreshes)
            #expect(!repository.shouldFetchFullServerList)
        }

        repository.recordSuccessfulRefresh()

        #expect(repository.consecutiveSuccessfulRefreshes == 0)
        #expect(repository.shouldFetchFullServerList)
    }

    @Test("Resetting the counter forces the next refresh to fetch the full server list")
    func resettingCounterForcesFullServerListFetch() {
        repository.recordSuccessfulRefresh()
        #expect(!repository.shouldFetchFullServerList)

        repository.resetSuccessfulRefreshes()

        #expect(repository.consecutiveSuccessfulRefreshes == 0)
        #expect(repository.shouldFetchFullServerList)
    }

    @Test("Treats an unparsable stored counter as zero")
    func treatsUnparsableCounterAsZero() {
        repository.setMetadata("not a number", for: .consecutiveSuccessfulRefreshes)

        #expect(repository.consecutiveSuccessfulRefreshes == 0)
        #expect(repository.shouldFetchFullServerList)
    }

    // MARK: - Logout

    @Test("Deleting all servers also clears the refresh metadata")
    func deletingAllServersClearsRefreshMetadata() {
        repository.upsert(servers: [TestData.createMockServer(withID: "free1", tier: 0)])
        repository.recordSuccessfulRefresh()
        repository.setMetadata("Sat, 01 Aug 2026 00:00:00 GMT", for: .lastModifiedFree)
        repository.setMetadata("Sat, 01 Aug 2026 00:00:00 GMT", for: .lastModifiedAll)

        repository.deleteAllServers()

        #expect(repository.isEmpty)
        #expect(repository.getMetadata(.lastModifiedFree) == nil)
        #expect(repository.getMetadata(.lastModifiedAll) == nil)
        #expect(repository.getMetadata(.consecutiveSuccessfulRefreshes) == nil)
        #expect(repository.shouldFetchFullServerList)
    }

    // MARK: - Conditional requests

    @Test("Scopes the last modified timestamp to the tier of the response")
    func scopesLastModifiedToResponseTier() {
        #expect(DatabaseMetadata.Key.lastModified(freeTier: true) == .lastModifiedFree)
        #expect(DatabaseMetadata.Key.lastModified(freeTier: false) == .lastModifiedAll)
    }
}
