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
        #expect(repository.shouldFetchFullServerList(language: "en"))
    }

    @Test("Fetches the full server list when the app language changed")
    func fetchesFullServerListAfterLanguageChange() {
        repository.setMetadata("en", for: .translationsLanguage)
        repository.recordSuccessfulRefresh()
        #expect(!repository.shouldFetchFullServerList(language: "en"))
        #expect(repository.shouldFetchFullServerList(language: "fr"))
    }

    @Test("Counts consecutive refreshes, wrapping back to a full server list fetch")
    func countsConsecutiveRefreshes() {
        repository.setMetadata("en", for: .translationsLanguage)
        for expectedRefreshes in 1 ..< ServerRepository.fullServerListRefreshInterval {
            repository.recordSuccessfulRefresh()

            #expect(repository.consecutiveSuccessfulRefreshes == expectedRefreshes)
            #expect(!repository.shouldFetchFullServerList(language: "en"))
        }

        repository.recordSuccessfulRefresh()

        #expect(repository.consecutiveSuccessfulRefreshes == 0)
        #expect(repository.shouldFetchFullServerList(language: "en"))
    }

    @Test("Resetting the counter forces the next refresh to fetch the full server list")
    func resettingCounterForcesFullServerListFetch() {
        repository.setMetadata("en", for: .translationsLanguage)
        repository.recordSuccessfulRefresh()
        #expect(!repository.shouldFetchFullServerList(language: "en"))

        repository.resetSuccessfulRefreshes()

        #expect(repository.consecutiveSuccessfulRefreshes == 0)
        #expect(repository.shouldFetchFullServerList(language: "en"))
    }

    @Test("Treats an unparsable stored counter as zero")
    func treatsUnparsableCounterAsZero() {
        repository.setMetadata("not a number", for: .consecutiveSuccessfulRefreshes)

        #expect(repository.consecutiveSuccessfulRefreshes == 0)
        #expect(repository.shouldFetchFullServerList(language: "en"))
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
        #expect(repository.shouldFetchFullServerList(language: "en"))
    }

    // MARK: - Conditional requests

    @Test(
        "Gives every scope of the server list its own last modified timestamp",
        arguments: [
            (ServerListScope.freeTier, DatabaseMetadata.Key.lastModifiedFree),
            (.allTiers, .lastModifiedAll),
            (.guestSession, .lastModifiedGuest),
        ]
    )
    func scopesLastModifiedToTheResponse(scope: ServerListScope, key: DatabaseMetadata.Key) {
        #expect(DatabaseMetadata.Key.lastModified(for: scope) == key)
    }

    @Test(
        "Only a full response counts as a baseline for another scope",
        arguments: [
            (ServerListScope.allTiers, [DatabaseMetadata.Key.lastModifiedAll, .lastModifiedFree]),
            (.freeTier, [.lastModifiedFree]),
            (.guestSession, [.lastModifiedGuest]),
        ]
    )
    func recordsTheBaselinesAResponseSpeaksFor(scope: ServerListScope, expected: [DatabaseMetadata.Key]) {
        let timestamp = "Sat, 01 Aug 2026 00:00:00 GMT"

        repository.recordServerList(scope: scope, lastModifiedAt: timestamp)

        for other in ServerListScope.allCases {
            let key = DatabaseMetadata.Key.lastModified(for: other)
            #expect(repository.getMetadata(key) == (expected.contains(key) ? timestamp : nil))
        }
    }

    @Test("Forgetting the baseline clears every scope")
    func forgettingTheBaselineClearsEveryScope() {
        for scope in ServerListScope.allCases {
            repository.recordServerList(scope: scope, lastModifiedAt: "Sat, 01 Aug 2026 00:00:00 GMT")
        }

        repository.deleteServerListBaseline()

        for scope in ServerListScope.allCases {
            #expect(repository.getMetadata(.lastModified(for: scope)) == nil)
        }
    }

    @Test("Requests against the stored baseline while the stored language matches the request's")
    func providesBaselineWhenLanguageMatches() {
        let timestamp = "Sat, 01 Aug 2026 00:00:00 GMT"
        repository.setMetadata("fr", for: .translationsLanguage)
        repository.recordServerList(scope: .freeTier, lastModifiedAt: timestamp)

        #expect(repository.logicalsRequestBaseline(scope: .freeTier, language: "fr") == timestamp)
    }

    @Test("Requests without a baseline after a language change, so the response arrives in full")
    func providesNoBaselineAfterLanguageChange() {
        repository.setMetadata("en", for: .translationsLanguage)
        repository.recordServerList(scope: .freeTier, lastModifiedAt: "Sat, 01 Aug 2026 00:00:00 GMT")

        #expect(repository.logicalsRequestBaseline(scope: .freeTier, language: "fr") == nil)
    }

    @Test("Requests without a baseline when no translations language was recorded")
    func providesNoBaselineWithoutRecordedLanguage() {
        repository.recordServerList(scope: .allTiers, lastModifiedAt: "Sat, 01 Aug 2026 00:00:00 GMT")

        #expect(repository.logicalsRequestBaseline(scope: .allTiers, language: "en") == nil)
    }

    // MARK: - Request scope

    @Test(
        "Asks for the scope the caller wanted while the stored names are in the right language",
        arguments: ServerListScope.allCases
    )
    func keepsTheRequestedScopeWhenTranslationsAreCurrent(scope: ServerListScope) {
        repository.setMetadata("fr", for: .translationsLanguage)

        #expect(repository.logicalsRequestScope(for: scope, language: "fr") == scope)
    }

    @Test("Asks for every tier after a language change, so no paid server keeps its old name")
    func widensAFreeTierRequestAfterALanguageChange() {
        repository.setMetadata("en", for: .translationsLanguage)

        #expect(repository.logicalsRequestScope(for: .freeTier, language: "fr") == .allTiers)
    }

    @Test(
        "Leaves a request that already covers every tier alone after a language change",
        arguments: [ServerListScope.allTiers, .guestSession]
    )
    func leavesFullScopesAloneAfterALanguageChange(scope: ServerListScope) {
        repository.setMetadata("en", for: .translationsLanguage)

        #expect(repository.logicalsRequestScope(for: scope, language: "fr") == scope)
    }
}
